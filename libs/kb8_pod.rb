require 'methadone'
require 'json'
require_relative 'kb8_controller'
require_relative 'kb8_run'

class Kb8Pod < Kb8Resource

  include Methadone::Main
  include Methadone::CLILogging

  PHASE_PENDING   = 'Pending'
  PHASE_RUNNING   = 'Running'
  PHASE_SUCCEEDED = 'Succeeded'
  PHASE_FAILED    = 'Failed'
  PHASE_UNKNOWN   = 'Unknown'

  CONDITION_NOT_READY     = :not_ready
  CONDITION_READY         = :ready
  CONDITION_RESTARTING    = :restarting
  CONDITION_ERR_WAIT      = :error_waiting

  EVENT_ERROR_PREFIX = 'failed'
  EVENT_UNHEALTHY = 'unhealthy'
  EVENT_REASONS = [EVENT_ERROR_PREFIX, EVENT_UNHEALTHY]

  FAIL_EVENT_ERROR_COUNT = 3
  MAX_CONTAINER_RESTARTS = 3
  RESTART_BACK_OFF_SECONDS = 10

  attr_reader :controller,
              :container_specs,
              :error_message,
              :failing_containers,
              :max_container_restarts,
              :pod_data,
              :restart_back_off_seconds,
              :restart_never,
              :volumes

  def initialize(pod_data, rc=nil, file=nil, context=nil)
    debug "setting pod_data=#{pod_data}"
    @pod_data = pod_data
    @controller = rc
    @container_specs = []
    if rc
      unless context
        context = rc.context
      end
    end
    if context
      @max_container_restarts = context.settings.max_container_restarts ||= MAX_CONTAINER_RESTARTS
      @restart_back_off_seconds = context.settings.restart_back_off_seconds ||= RESTART_BACK_OFF_SECONDS

      pod_data['spec']['containers'].each do |item|
        container = Kb8ContainerSpec.new(item)
        container.update(context)
        @container_specs << container
      end
    end
    @restart_never = false
    @restart_never = @pod_data['spec']['restartPolicy'] == 'Never'
    @failing_containers = []
    if @pod_data['spec'].has_key?('volumes')
      @volumes = Kb8Volumes.new(@pod_data['spec']['volumes'])
    else
      @volumes = []
    end

    # Initialize the base kb8 resource
    super(pod_data, file)
  end

  def name
    @pod_data['metadata']['name']
  end

  def refresh(refresh=true)
    all_pod_data = []
    if @controller
      debug 'Controller is set...'
      @controller.refresh_status(refresh)

      all_pod_data = @controller.pod_status_data['items']
    else
      debug 'Single Pod...'
      data = data(refresh)
      unless data
        data = @pod_data
      end
      all_pod_data << data
    end

    all_pod_data.each do | possible_pod |
      debug "name:#{name}"
      if possible_pod.nil?
        debug "how?"
      end
      debug "Poss pod name:#{possible_pod['metadata']['name']}"
      if possible_pod['metadata']['name'] == name
        @pod_data = possible_pod
      end
    end
  end

  def phase(refresh=false)
    refresh(refresh)
    phase = PHASE_UNKNOWN
    if @pod_data
      unless @pod_data['status'].nil?
        unless @pod_data['status']['phase'].nil?
          phase = @pod_data['status']['phase']
        end
      end
    end
    phase
  end

  def update_error(message)
    if @error_message
      @error_message << "\n"
    else
      @error_message = "\t"
    end
    unless @error_message.to_s.include?(message)
      @error_message << message
    end
  end

  def is_event_reason_relevant(reason)
    EVENT_REASONS.each do |event_reason|
      if reason.downcase.start_with?(event_reason.downcase)
        return true
      end
    end
    false
  end

  def is_ready?
    ready = false
    if @pod_data
      unless @pod_data['status']
        debug 'No status here...'
        # Can't see anything more for now...
        return false
      end

      if @pod_data['status']['conditions']
        debug "condition:#{@pod_data['status']['conditions']}"
        @pod_data['status']['conditions'].each do |pod_condition|
          debug "condition:#{pod_condition}"
          if pod_condition['type'] == 'Ready'
            ready = pod_condition['status'] == 'True'
          end
        end
      end
      if restart_never
        # Have to manage 'phase' here for controller less pods...
        ready = @pod_data['status']['phase'] == Kb8Pod::PHASE_SUCCEEDED
      end
    end
    ready
  end

  def condition(refresh=true)
    # TODO: work out if any container is healthy or just restarting!
    condition_value = Kb8Pod::CONDITION_NOT_READY
    refresh(refresh)
    debug "Pod-data:#{@pod_data.to_json}"

    # Find the 'Ready' condition...
    if is_ready?
      condition_value = Kb8Pod::CONDITION_READY
    end
    # Ensure things are actually good to go:
    # Will detect containers having events with reason='failed'
    debug "About to check container status' for pod:#{name}"
    if  @pod_data && @pod_data['status'] && @pod_data['status'].has_key?('containerStatuses')
      debug 'Container status found!'
      @pod_data['status']['containerStatuses'].each do | container_status |
        # Verify if we have any errors for this pod e.g.
        # state:
        #     waiting:
        #       reason: 'Error: image lev_ords_waf:0.5 not found'
        debug "Digging into container status #{container_status.to_json}"
        if container_status['state'].nil?
          condition_value = update_from_events(condition_value, container_status)
        else
          if container_status['state'].has_key?('waiting') &&
              container_status['state']['waiting']['reason'].downcase == 'pullimageerror'
            update_error(container_status['state']['waiting']['message'])
            condition_value = Kb8Pod::CONDITION_ERR_WAIT
            update_failing_containers(container_status)
          end
        end
        if container_status['restartCount']
          if container_status['restartCount'] >= max_container_restarts
            debug "Container restarting:'#{container_status['name']}'"
            update_failing_containers(container_status)
            condition_value = Kb8Pod::CONDITION_RESTARTING
          end
          if container_status['restartCount'] > 0
            show_container_logs(container_status['name'])
            puts "...Detected restarting container:'#{container_status['name']}'. Backing off to check again in #{restart_back_off_seconds}"
            sleep restart_back_off_seconds
          end
        end
        # Can do something more generic - if no controller but for now:
        if @restart_never
          # Probably a bad Pod:
          if container_status.has_key?('state')
            if container_status['state'].has_key?('terminated')
              exit_code = container_status['state']['terminated']['exitCode']
              if exit_code != 0
                update_error("Container terminated:'#{container_status['name']}' with exit code:#{exit_code}")
                update_failing_containers(container_status)
                condition_value = Kb8Pod::PHASE_FAILED
              end
            end
          end
        end
      end
    else
      debug 'No status found here...'
    end
    @last_condition = condition_value
    condition_value
  end

  def update_from_events(condition_value, container_status)
    # Now look up to see if any events are in error for this pod...
    # Assume the last event for this Pod is the only one in play?
    # TODO: add a refresh model to this...
    all_events = Kb8Run.get_pod_events(@name)
    last_event = all_events.last
    debug "Last event data:#{last_event.to_json}"
    if last_event && is_event_reason_relevant(last_event['reason'].to_s)
      debug "Event reason:#{last_event['reason']}, count:#{last_event['count']}"
      if last_event['count'] >= FAIL_EVENT_ERROR_COUNT ||
          container_status['restartCount'] >= max_container_restarts
        # Concatenate all error messages for this POD:
        all_events.each do | event |
          update_error(event['message']) if is_event_reason_relevant(event['reason'])
        end
        update_error(error_message)
        condition_value = Kb8Pod::CONDITION_ERR_WAIT
        update_failing_containers(container_status)
      end
    end
    condition_value
  end

  def update_failing_containers(container_status)
    unless @failing_containers.include?(container_status['name'])
      @failing_containers << container_status['name']
    end
  end

  def create
    # Ensure the Pod resource is created using the parent class...
    super

    # TODO: rewrite as health method / object...
    print "Waiting for '#{@name}'"
    $stdout.flush
    debug ''
    current_condition = nil
    loop do
      sleep 1
      current_condition = condition(true)
      Deploy.print_progress
      break if current_condition != Kb8Pod::CONDITION_NOT_READY
    end
    if current_condition == Kb8Pod::CONDITION_READY
      debug "All good for #{@name}"
    else
      puts ''
      mark_dirty
      report_on_pod_failure
      exit 1
    end
  end

  def show_container_logs(container_name)
    puts "Failing pod logs below for pod:'#{@name}', container:#{container_name}"
    puts '=============================='
    puts Kb8Run.get_pod_logs(@name, container_name)
    puts '=============================='
    puts "Failing pod logs above for pod:'#{@name}', container:#{container_name}"
  end

  def report_on_pod_failure
    puts 'Error, failing pods...'
    puts "Error messages for pod:#{@name}"
    puts @error_message
    debug "Err Status:#{@last_condition.to_s}"
    unless @last_condition == Kb8Pod::CONDITION_ERR_WAIT
      @failing_containers.each do |container_name|
        show_container_logs(container_name)
      end
    end
  end
end
