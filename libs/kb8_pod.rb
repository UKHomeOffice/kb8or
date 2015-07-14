require 'methadone'
require_relative 'kb8_controller'

class Kb8Pod

  PHASE_PENDING   = 'Pending'
  PHASE_RUNNING   = 'Running'
  PHASE_SUCCEEDED = 'Succeeded'
  PHASE_FAILED    = 'Failed'
  PHASE_UNKNOWN   = 'Unknown'

  attr_reader :pod_data,
              :replication_controller

  def initialize(pod_data, replication_controller)
    @pod_data = pod_data
    @replication_controller = replication_controller
  end

  def name
    @pod_data['metadata']['name']
  end

  def refresh(refresh=true)
    @replication_controller.refresh_status(refresh)

    all_pod_data = @replication_controller.pod_status_data
    all_pod_data['items'].each do | possible_pod |
      if possible_pod['metadata']['name'] == name
        @pod_data = possible_pod
      end
    end
  end

  def phase(refresh=false)
    refresh(refresh)
    @pod_data['status']['phase']
  end

  def containers_health(container_data)
    # TODO: work out if any container is just restarting!
    refresh(refresh)

    if @pod_data['status'].has_key?('containerStatuses')
      @pod_data['items'][0]['status']['containerStatuses'].each do | container_data |
        # Only update aggregate running state at end
        # Only update all_running flag if the aggregate state isn't already changed
        if aggregate_status == STATUS_UNKNOWN
          if container_data['state'].has_key?(STATUS_RUNNING)
            all_running = true
          end
        end
        if container_data['state'].has_key?(STATUS_WAITING)
          # TODO check restart count here...?
          aggregate_status = STATUS_WAITING unless aggregate_status == STATUS_TERMINATED
        end
        if container_data['state'].has_key?(STATUS_TERMINATED)
          aggregate_status = STATUS_TERMINATED
        end
      end
      if aggregate_status == STATUS_UNKNOWN and all_running
        return STATUS_RUNNING
      end
    end
    return aggregate_status
  end
end