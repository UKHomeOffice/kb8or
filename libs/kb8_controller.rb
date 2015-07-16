require 'methadone'
require_relative 'kb8_resource'
require_relative 'kb8_container_spec'
require_relative 'kb8_pod'

class Kb8Controller < Kb8Resource

  include Methadone::Main
  include Methadone::CLILogging

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

    @pods = []
    @container_specs = []

    # Initialise the selectors used to find relevant pods
    yaml_data['spec']['selector'].each do |key, value|
      @selector_key = key.to_s
      @selector_value = value.to_s
      break
      #TODO: handle more than one set of selectors e.g. versions?
    end
    @intended_replicas = yaml_data['spec']['replicas']

    # Now get the containers and set versions and private registry where applicable
    yaml_data['spec']['template']['spec']['containers'].each do |item|
      container = Kb8ContainerSpec.new(item)
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
      @pod_status_data = Kb8Run.get_pod_status(selector_key, selector_value)
    end
  end

  def create

    # Ensure the controller resource is created using the parent class...
    super

    # TODO: rewrite as health method / object...
    # Now wait until the pods are all running or one...
    phase_status = Kb8Pod::PHASE_UNKNOWN
    print "Waiting for controller #{@name}"
    $stdout.flush
    loop do
      # TODO: add a timeout option (or options for differing states...)
      sleep 1
      # Tidy sdtout when debugging...
      debug "\n"

      phase_status = aggregate_phase(true)
      debug "Aggregate pod status:#{phase_status}"
      print '.'
      $stdout.flush
      break if phase_status != Kb8Pod::PHASE_PENDING &&
               phase_status != Kb8Pod::PHASE_UNKNOWN
    end
    # add new line after content above...
    puts ''
    if phase_status == Kb8Pod::PHASE_FAILED
      # TODO: some troubleshooting - at least show the logs!
      puts "Controller #{@name} entered failed state!"
      @pods.each do | pod |
        puts "Pod:#{pod.name}, status:#{pod.error_message}" if pod.error_message
      end
      exit 1
    end

    # Now check health of all pods...
    failed_pods = []
    condition = Kb8Pod::CONDITION_NOT_READY
    @pods.each do | pod |
      print "Waiting for #{pod.name}"
      $stdout.flush
      loop do
        sleep 1
        condition = pod.condition(true)
        print '.'
        $stdout.flush
        break if condition != Kb8Pod::CONDITION_NOT_READY
      end
      if condition == Kb8Pod::CONDITION_READY
        debug "All good for #{pod.name}"
      else
        failed_pods << pod
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
      debug "Reloading pod data..."
      # First get all the pods...
      @actual_replicas = @pod_status_data['items'].count
      debug "Actual pods running:#{@actual_replicas}"
      debug "Intended pods running:#{@intended_replicas}"

      @pods = []
      if @actual_replicas == @intended_replicas
        debug "All replicas loaded..."
        @pod_status_data['items'].each do | pod |
          @pods << Kb8Pod.new(pod, self)
        end
        debug "All pods loaded..."
      else
        debug "Invalid number of replicas - need we wait?"
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
    get_pod_data(refresh)
    aggregate_phase = Kb8Pod::PHASE_UNKNOWN
    running_count = 0

    @pods.each do | pod |
      debug "Phase:#{pod.phase}"
      case pod.phase
        when Kb8Pod::PHASE_RUNNING
          # TODO check restart count here...?
          running_count = running_count + 1
        when Kb8Pod::PHASE_FAILED
          aggregate_phase = Kb8Pod::PHASE_FAILED
        when Kb8Pod::PHASE_PENDING
          # check pod conditions...
          condition = pod.condition(false)
          if condition == Kb8Pod::CONDITION_ERR_WAIT
            aggregate_phase = Kb8Pod::PHASE_FAILED
          end
          aggregate_phase = Kb8Pod::PHASE_PENDING unless aggregate_phase == Kb8Pod::PHASE_FAILED
        else
          # Nothing to do here...
      end
    end
    # If the phase has at least been discovered and all pods running, then...
    if aggregate_phase == Kb8Pod::PHASE_UNKNOWN && running_count == @pods.count
      aggregate_phase = Kb8Pod::PHASE_RUNNING
    end
    aggregate_phase
  end
end