require 'methadone'
require 'json'
require_relative 'kb8_controller'

class Kb8Pod

  include Methadone::Main
  include Methadone::CLILogging

  PHASE_PENDING   = 'Pending'
  PHASE_RUNNING   = 'Running'
  PHASE_SUCCEEDED = 'Succeeded'
  PHASE_FAILED    = 'Failed'
  PHASE_UNKNOWN   = 'Unknown'

  CONDITION_NOT_READY  = :not_ready
  CONDITION_READY      = :ready
  CONDITION_RESTARTING = :restarting

  attr_reader :pod_data,
              :replication_controller

  def initialize(pod_data, rc)
    debug "setting pod_data=#{pod_data}"
    @pod_data = pod_data
    @replication_controller = rc
  end

  def name
    @pod_data['metadata']['name']
  end

  def refresh(refresh=true)
    @replication_controller.refresh_status(refresh)

    all_pod_data = @replication_controller.pod_status_data

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

    unhealthy_containers = []
    debug "Pod-data:#{@pod_data.to_json}"

    # Find the 'Ready' condition...
    ready = false
    if @pod_data
      debug "condition:#{@pod_data['status']['Condition']}"
      @pod_data['status']['Condition'].each do |condition|
        debug "condition:#{condition}"
        if condition['type'] == 'Ready'
          ready = condition['status'] == 'True'
        end
      end
    end

    if ready
      condition_value = Kb8Pod::CONDITION_READY

      # TODO: Check restart count
      # @pod_data['items'][0]['status']['containerStatuses'].each do | container_data |
      #
      # end


      # TODO: Decide on other reasons to detect failed readyness (e.g. timeout)
    end
    condition_value
  end
end
