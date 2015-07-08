require_relative 'kb8_resource'

class Kb8Controller < Kb8Resource

  attr_accessor :selector_key,
                :selector_value,
                :pods

  GET_POD = "kubectl get pods -l %1=%2 -o json"
  ROLLING_UPDATE_CMD = "| kubectl rolling-update %s-v%s -f -"
  RUNNING = 'Running'

  def initialize(yaml_data, file)
    super(yaml_data, file)
    @pods = []
    yaml_data['spec']['selector'].each do |key, value|
      @selector_key = key.to_s
      @selector_value = value.to_s
    end
    # Now get the first container and initial version
    yaml_data['spec']['template']['spec']['containers'].each do |item|
      @pods << Kb8Pod.new(item, self)
    end
  end

  def to_version
    pods[0].to_version
  end

  def current_version
    pods[0].current_version
  end

  def refresh_status
    get_pods = GET_POD % @replication_controller.selector_key,
        @replication_controller.selector_value
    kb8_out = `kubectl #{get_pods}`
    @pod_status_data = YAML.load(kb8_out)
  end

  # Will get the pod status or the last requested pod status
  # unless refresh is specified
  def status(refresh=false)
    if @pod_status_data.nil?
      refresh = true
    end
    refresh_status if refresh
    case @pod_status_data['items'].count
      when 0
        false
      when 1
        @pod_status_data['items'][0]['status']['phase'] == RUNNING
    end
  end

  def pod_status(pod_name, refresh=false)
    status(refresh)
    @pod_status_data['items'][0]['status']['containerStatuses'].each do | container_data |
      if container_data['name'] == pod_name
        return container_data['state'].has_key?('running')
      end
    end
  end
end
