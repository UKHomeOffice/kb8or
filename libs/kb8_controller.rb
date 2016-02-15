require 'methadone'
require_relative 'kb8_resource'
require_relative 'kb8_container_spec'
require_relative 'kb8_pod'

class Kb8Controller < Kb8Resource

  include Methadone::Main
  include Methadone::CLILogging

  DEPLOYMENT_LABEL = 'kb8_deploy_id'
  ORIGINAL_NAME = 'kb8_deploy_name'

  attr_accessor :selectors,
                :container_specs,
                :context,
                :pod_status_data,
                :pods,
                :intended_replicas,
                :actual_replicas,
                :new_deploy_id,
                :volumes

  class Selectors
    attr_accessor :selectors_hash

    def initialize(selectors_data)
      @selectors_hash = selectors_data
    end

    def to_s
      # Create a sorted key value string
      selector_string = ''
      @selectors_hash.keys.sort.each do | key |
        unless selector_string == ''
          selector_string = selector_string + ','
        end
        selector_string = "#{selector_string}#{key}=#{@selectors_hash[key]}"
      end
      selector_string
    end

    def ==(other_obj)
      (self.to_s == other_obj.to_s)
    end
  end

  def initialize(yaml_data, file, context)

    # Initialize the base kb8 resource
    super(yaml_data, file)

    @container_specs = []
    @no_rolling_updates = context.settings.no_rolling_update
    @context = context

    # Initialise the selectors used to find relevant pods
    unless yaml_data['spec']
      raise "Invalid YAML - Missing spec in file:'#{file}'."
    end
    unless yaml_data['spec'].has_key?('selector')
      raise "Invalid YAML - Missing selectors in file:'#{file}'."
    end
    @selectors = Selectors.new(yaml_data['spec']['selector'])
    @intended_replicas = yaml_data['spec']['replicas']
    @pods = []

    # Now get the containers and set versions and private registry where applicable
    containers = []
    begin
      containers = yaml_data['spec']['template']['spec']['containers']
    rescue Exception => e
      raise $!, "Invalid YAML - Missing containers in controller file:'#{file}'.", $!.backtrace
    end
    containers.each do |item|
      container = Kb8ContainerSpec.new(item)
      container.update(context)
      @container_specs << container
    end
    if yaml_data['spec']['template']['spec'].has_key?('volumes')
      @volumes = Kb8Volumes.new(yaml_data['spec']['template']['spec']['volumes'])
    else
      @volumes = []
    end
    update_md5
  end

  def can_roll_update?
    if @no_rolling_updates
      return false
    end
    if exist?
      @live_data['metadata']['labels'].has_key?(DEPLOYMENT_LABEL)
    else
      false
    end
  end

  def deploy_id
    unless @new_deploy_id
      deploy_id = '0'
      if data && data['metadata'] && data['metadata']['labels'] &&
          data['metadata']['labels'].has_key?(DEPLOYMENT_LABEL)
        deploy_id = data['metadata']['labels'][DEPLOYMENT_LABEL]
      end
      # Grab the first digits...
      id = deploy_id.match(/[\d]+/).to_a.first
      unless id
        # We have the field but no digits so set back to 0
        id = 0
      end
      @new_deploy_id = "v#{id.to_i + 1}"
    end
    @new_deploy_id
  end

  def update_deployment_data
    # Add new deployment id and name etc...
    @yaml_data['metadata']['name'] = "#{@original_name}-#{deploy_id}"
    unless @yaml_data['metadata']['labels']
      @yaml_data['metadata']['labels'] = {}
    end
    @yaml_data['metadata']['labels'][ORIGINAL_NAME] = @original_name
    @yaml_data['metadata']['labels'][DEPLOYMENT_LABEL] = deploy_id
    @yaml_data['spec']['selector'][DEPLOYMENT_LABEL] = deploy_id
    @yaml_data['spec']['template']['metadata']['labels'][DEPLOYMENT_LABEL] = deploy_id
  end

  def refresh_status(refresh=false)
    if @pod_status_data.nil?
      refresh = true
    end
    if refresh
      @pod_status_data = Kb8Run.get_pod_status(@selectors.to_s)
    end
  end

  def update
    unless exist?
      raise "Can't update #{@kind}/#{@name} as it doesn't exist yet!"
    end
    unless can_roll_update?
      delete
      create
    else
      yaml_string = YAML.dump(yaml_data)
      begin
        update_deployment_data
        Kb8Run.rolling_update(yaml_string, @live_data['metadata']['name'])
        @name = yaml_data['metadata']['name']
      ensure
        check_status
      end
    end
  end

  def delete
    super
    debug 'Waiting for delete to succeed...'
    # Wait for all pods to go...
    @pods.each do |pod|
      while pod.exist?(true) do
        sleep(1)
      end
    end
  end

  def exist?(refresh=false)
    exists = false
    if super(refresh)
      exists = true
    else
      @resources_of_kind['items'].each do |item|
        if item
          unless item['metadata'].nil?
            unless item['metadata']['labels'].nil?
              if item['metadata']['labels'][ORIGINAL_NAME] == @original_name
                if namespace_match?(item)
                  @live_data = item
                  @name = @live_data['metadata']['name']
                  exists = true
                end
              end
            end
          end
        end
      end
    end
    exists
  end

  def create
    # Ensure the controller resource is created using the parent class...
    update_deployment_data
    super
    check_status
  end

  def check_status
    # TODO: rewrite as health method / object...
    # Now wait until the pods are all running or one...
    phase_status = Kb8Pod::PHASE_UNKNOWN
    print "Waiting for controller #{@name}"
    $stdout.flush
    loop do
      # TODO: add a timeout option (or options for differing states...)
      sleep 1
      # Tidy stdout when debugging...
      debug "\n"

      phase_status = aggregate_phase(true)
      debug "Aggregate pod status:#{phase_status}"
      Deploy.print_progress
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
      mark_dirty
      exit 1
    end

    # Now check health of all pods...
    failed_pods = []
    condition = Kb8Pod::CONDITION_NOT_READY
    @pods.each do | pod |
      print "Waiting for '#{pod.name}'"
      $stdout.flush
      loop do
        sleep 1
        condition = pod.condition(true)
        Deploy.print_progress
        break if condition != Kb8Pod::CONDITION_NOT_READY
      end
      print "\n"
      if condition == Kb8Pod::CONDITION_READY
        debug "All good for #{pod.name}"
      else
        failed_pods << pod
      end
    end
    unless failed_pods.count < 1
      mark_dirty
      failed_pods.each do | pod |
        pod.report_on_pod_failure
      end
      exit 1
    end
  end

  def mark_dirty
    @pods.each do |pod|
      pod.mark_dirty
    end
  end

  def is_dirty?
    if exist?
      get_pod_data(true)
      @pods.each do |pod|
        if pod.is_dirty?
          return true
        end
      end
    end
    false
  end

  def get_pod_data(refresh=true)
    refresh_status(refresh)

    if refresh || (!@pods)
      debug 'Reloading pod data...'
      # First get all the pods...
      @actual_replicas = @pod_status_data['items'].count
      debug "Actual pods running:#{@actual_replicas}"
      debug "Intended pods running:#{@intended_replicas}"

      @pods = []
      @pod_status_data['items'].each do | pod |
        @pods << Kb8Pod.new(pod, self)
      end
    end
    @pods
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