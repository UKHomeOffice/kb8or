require_relative 'kb8_resource'
require_relative 'kb8_container_spec'
require_relative 'kb8_pod'

class Kb8Controller < Kb8Resource

  attr_accessor :selector_key,
                :selector_value,
                :container_specs,
                :pod_status_data,
                :pods,
                :intended_replicas,
                :actual_replicas

  def initialize(yaml_data, file, context)

    # Initialize the base kb8 resource
    super(yaml_data, file)

    @container_specs = []

    # Initialise the selectors used to find relevant pods
    yaml_data['spec']['selector'].each do |key, value|
      @selector_key = key.to_s
      @selector_value = value.to_s
      break
      #TODO: handle more than one set of selectors e.g. versions?
    end
    @intended_replicas = yaml_data['spec']['selector']

    # Now get the containers and set versions and private registry where applicable
    yaml_data['spec']['template']['spec']['containers'].each do |item|
      container = Kb8ContainerSpec.new(item, self)
      if context.container_version_finder
        # Overwrite the version and registry used:
        version = context.container_version_finder.get_version(container.image_name, container.version)
        container.set_version(version)
        # Set private registry (if defined)...
        container.set_registry(context.settings.private_registry) if context.settings.use_private_registry
      end
      @container_specs << container
    end
  end

  def refresh_status(refresh=false)
    if @pod_status_data.nil?
      refresh = true
    end
    if refresh
      debug 'Checking pod status...'
      @pod_status_data = Kb8Run.get_pod_status(selector_key, selector_value)
    end
  end

  def create

    # Ensure the controller resource is created using the parent class...
    super

    # TODO: rewrite as health method / object...
    # Now wait until the pods are all running or one...
    loop do
      $stdout.flush
      print "Waiting for controller #{@name}"
      sleep 1

      phase_status = aggregate_phase(true)
      debug "Controller status:#{status}"
      print '.'
      $stdout.flush
      break if phase_status != Kb8Pod::PHASE_PENDING
    end
    if phase_status == Kb8Pod::PHASE_FAILED
      # TODO: some troubleshooting - at least show the logs!
      puts "Controller #{@name} entered failed state!"
      exit 1
    end

    # Now check health of pods...
    failed_pods = []
    @container_specs.each do | pod |
      print "Waiting for #{pod.name}"
      loop do
        $stdout.flush
        sleep 1

        pod_phase_status = pod.containers_state(true)
        debug "Pod status:#{pod_phase_status}"
        print '.'
        $stdout.flush
        if pod_phase_status != Kb8ContainerSpec::STATUS_WAITING ||
           pod_phase_status == Kb8ContainerSpec::STATUS_UNKNOWN
          failed_pods << pod
          break
        end
      end
    end
    unless failed_pods.count < 1
      # TODO: add some diagnostics e.g. logs and which failed...
      puts "Some failed pods..."
      exit 1
    end
  end

  def get_pod_data(refresh=true)
    refresh_status(refresh)

    if refresh || (!@pods)
      # First get all the pods...
      @actual_replicas = @pod_status_data['items'].count
      if @actual_replicas == @intended_replicas
        @pod_status_data['items'].each do | pod |
          @pods << Kb8Pod(pod, self)
        end
      end
    end
  end

  # Will get the controller status or the last requested controller status
  # unless refresh is specified
  def aggregate_phase(refresh=false)

    # Return aggregate phase of all pods set to run:
    # 'Pending'
    # 'Running'
    # 'Succeeded'
    # 'Failed'
    # If ALL PODS Running, return Running
    # if ANY Failed set to Failed
    # If ANY Pending set to Pending (unless any set to Failed)
    aggregate_phase = Kb8Pod::PHASE_UNKNOWN
    running_count = 0

    @pods.each do | pod |
      if aggregate_status == Kb8Pod::PHASE_UNKNOWN
        if pod.phase == Kb8Pod::PHASE_RUNNING
          # TODO check restart count here...?
          running_count = running_count + 1
        end
        if pod.phase == Kb8Pod::PHASE_PENDING
          aggregate_status = Kb8Pod::PHASE_PENDING unless aggregate_status == Kb8Pod::PHASE_FAILED
        end
        if pod.phase == Kb8Pod::PHASE_FAILED
          aggregate_status = Kb8Pod::PHASE_FAILED
        end
      end
    end
    if aggregate_status == Kb8Pod::PHASE_UNKNOWN && running_count == @pods.count
      return Kb8Pod::PHASE_RUNNING
    end
    Kb8Pod::PHASE_UNKNOWN
  end
end