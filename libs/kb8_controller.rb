require_relative 'kb8_resource'

class Kb8Controller < Kb8Resource

  attr_accessor :selector_key,
                :selector_value,
                :pods,
                :pod_status_data

  RUNNING = 'Running'

  def initialize(yaml_data, file, context)

    # Initialize the base resource
    super(yaml_data, file)

    @pods = []
    yaml_data['spec']['selector'].each do |key, value|
      @selector_key = key.to_s
      @selector_value = value.to_s
      break
      #TODO: handle more than one set of selectors?
    end
    # Now get the first container and initial version
    yaml_data['spec']['template']['spec']['containers'].each do |item|
      pod = Kb8Pod.new(item, self)
      if context.container_version_finder
        # Overwrite the version and registry used:
        version = context.container_version_finder.get_version(pod.image_name, pod.version)
        pod.set_version(version)
        # Set private registry (if defined)...
        pod.set_registry(context.settings.private_registry) if context.settings.use_private_registry
      end
      @pods << pod
    end
  end

  def to_version
    pods[0].to_version
  end

  def current_version
    pods[0].current_version
  end

  def refresh_status
    @pod_status_data = Kb8Run.get_pod_status(selector_key, selector_value)
  end

  def create
    # Ensure the YAML is refreshed...
    @pods.each do |pod|
      pod.refresh_data
    end
    super

    # TODO: Now wait until the pods are all running...
    @pods.each do |pod|
      print "Waiting for #{pod.name}"
      begin
        $stdout.flush
        sleep 1

        debug "Pod running:#{pod.running}"
        print '.'
        $stdout.flush
      end until pod.running(false)
    end
  end

  # Will get the pod status or the last requested pod status
  # unless refresh is specified
  def status(refresh=false)
    if @pod_status_data.nil?
      refresh = true
    end
    debug 'Checking pod status...' if refresh
    refresh_status if refresh
    case @pod_status_data['items'].count
      when 0
        false
      when 1
        @pod_status_data['items'][0]['status']['phase'] == RUNNING
    end
  end
end
