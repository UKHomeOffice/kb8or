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

  FAIL_EVENT_ERROR_COUNT = 3
  FAIL_CONTAINER_RESTART_COUNT = 3

  attr_reader :pod_data,
              :controller,
              :container_specs,
              :error_message

  def initialize(pod_data, rc=nil, file=nil, context=nil)
    debug "setting pod_data=#{pod_data}"
    @pod_data = pod_data
    @controller = rc
    @container_specs = []
    if context
      pod_data['spec']['containers'].each do |item|
        container = Kb8ContainerSpec.new(item)
        container.update(context)
        @container_specs << container
      end
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
      debug "Controller is set..."
      @controller.refresh_status(refresh)

      all_pod_data = @controller.pod_status_data['items']
    else
      debug "Single Pod..."
      all_pod_data << data(refresh)
    end

    all_pod_data.each do | possible_pod |
      debug "name:#{name}"
      debug "Poss pod name:#{possible_pod['metadata']['name']}"
      if possible_pod['metadata']['name'] == name
        @pod_data = possible_pod
      end
    end
  end

  def phase(refresh=false)
    refresh(refresh)
    @pod_data['status']['phase']
  end

  def update_error(message)
    if @error_message
      @error_message << "\n"
    else
      @error_message = ''
    end
    @error_message << message
  end

  def condition(refresh=true)

    # TODO: work out if any container is healthy or just restarting!
    condition_value = Kb8Pod::CONDITION_NOT_READY

    restart_never = false
    restart_never = @pod_data['spec']['restartPolicy'] == 'Never'

    refresh(refresh)

    debug "Pod-data:#{@pod_data.to_json}"

    # Find the 'Ready' condition...
    ready = false
    if @pod_data
      debug "condition:#{@pod_data['status']['conditions']}"
      if @pod_data['status']['conditions']
        @pod_data['status']['conditions'].each do |condition|
          debug "condition:#{condition}"
          if condition['type'] == 'Ready'
            ready = condition['status'] == 'True'
          end
        end
      end
      if restart_never
        # Have to manage 'phase' here for controller less pods...
        ready = @pod_data['status']['phase'] == Kb8Pod::PHASE_SUCCEEDED
      end
    end
    debug "Ready:#{ready}"
    if ready
      condition_value = Kb8Pod::CONDITION_READY
    end
    # Ensure things are actually good to go:
    # Will detect containers having events with reason='failed'
    debug "Here"
    if @pod_data['status'].has_key?('containerStatuses')
      debug "Container status found!"
      @pod_data['status']['containerStatuses'].each do | container_status |
        # Verify if we have any errors for this pod e.g.
        # state:
        #     waiting:
        #       reason: 'Error: image lev_ords_waf:0.5 not found'
        debug "Digging into container status #{container_status.to_json}"
        if container_status['state'].has_key?('waiting')
          # Now look up to see if any events are in error for this pod...
          # Assume the last event for this Pod is the only one in play?
          # TODO: add a refresh model to this...
          all_events = Kb8Run.get_pod_events(name)
          last_event = all_events.last
          debug "Last event data:#{last_event.to_json}"
          if last_event && last_event['reason'].to_s.start_with?(EVENT_ERROR_PREFIX)
            debug "Event reason:#{last_event['reason']}, count:#{last_event['count']}"
            if last_event['count'] >= FAIL_EVENT_ERROR_COUNT ||
                container_status['restartCount'] >= FAIL_CONTAINER_RESTART_COUNT
              # Concatignate all error messages for this POD:
              all_events.each do | event |
                error_message << event['message'] if event['reason'].start_with?(EVENT_ERROR_PREFIX)
              end
              update_error(error_message)
              condition_value = Kb8Pod::CONDITION_ERR_WAIT
            end
          end
        end
        if container_status['restartCount'] >= FAIL_CONTAINER_RESTART_COUNT
          debug "Container restarting: #{container_status['name']}"
          condition_value = Kb8Pod::CONDITION_RESTARTING
        end
        # Can do something more generic - if no controller but for now:
        if @pod_data['spec']['restartPolicy'] == 'Never'
          # Probably a bad Pod:
          if container_status.has_key?('state')
            if container_status['state'].has_key?('terminated')
              exit_code = container_status['state']['terminated']['exitCode']
              if exit_code != 0
                update_error("Container terminated:'#{container_status['name']}' with exit code:#{exit_code}")
                condition_value = Kb8Pod::PHASE_FAILED
              end
            end
          end
        end
      end
    else
      debug "No status found here..."
    end
    condition_value
  end

  def create
    # Ensure the Pod resource is created using the parent class...
    super

    # TODO: rewrite as health method / object...
    print "Waiting for '#{@name}'"
    $stdout.flush
    debug ""
    loop do
      sleep 1
      condition = condition(true)
      Deploy.print_progress
      break if condition != Kb8Pod::CONDITION_NOT_READY
    end
    if condition == Kb8Pod::CONDITION_READY
      debug "All good for #{@name}"
    else
      # TODO: add some diagnostics e.g. logs and which failed...
      puts "Error, failing pods..."
      puts ''
      puts "Failing pod logs below for pod:#{@name}"
      puts '=============================='
      Kb8Run.get_pod_logs(@name)
      puts '=============================='
      puts "Failing pod logs above for pod:#{@name}"
      exit 1
    end
  end
end
