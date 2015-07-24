require 'methadone'
require 'json'
require_relative 'kb8_controller'
require_relative 'kb8_run'

class Kb8Pod

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

  FAIL_EVENT_ERROR_COUNT = 2
  FAIL_CONTAINER_RESTART_COUNT = 3

  attr_reader :pod_data,
              :replication_controller,
              :error_message

  def initialize(pod_data, rc)
    debug "setting pod_data=#{pod_data}"
    @pod_data = pod_data
    @controller = rc
  end

  def name
    @pod_data['metadata']['name']
  end

  def refresh(refresh=true)
    @controller.refresh_status(refresh)

    all_pod_data = @controller.pod_status_data

    all_pod_data['items'].each do | possible_pod |
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

  def condition(refresh=true)

    # TODO: work out if any container is healthy or just restarting!
    condition_value = Kb8Pod::CONDITION_NOT_READY

    refresh(refresh)

    debug "Pod-data:#{@pod_data.to_json}"

    # Find the 'Ready' condition...
    ready = false
    if @pod_data
      debug "condition:#{@pod_data['status']['Condition']}"
      if @pod_data['status']['Condition']
        @pod_data['status']['Condition'].each do |condition|
          debug "condition:#{condition}"
          if condition['type'] == 'Ready'
            ready = condition['status'] == 'True'
          end
        end
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
            if last_event['count'] > FAIL_EVENT_ERROR_COUNT
              # Concatignate all error messages for this POD:
              all_events.each do | event |
                if @error_message
                  @error_message << "\n"
                else
                  @error_message = ''
                end
                error_message << event['message'] if event['reason'].start_with?(EVENT_ERROR_PREFIX)
              end
              @error_message = error_message
              condition_value = Kb8Pod::CONDITION_ERR_WAIT
            end
          end
        end
        if container_status['restartCount'] >= FAIL_CONTAINER_RESTART_COUNT
          debug "Container restarting: #{container_status['name']}"
          condition_value = Kb8Pod::CONDITION_RESTARTING
        end
      end
    else
      debug "No status found here..."
    end
    condition_value
  end
end
