#!/usr/bin/env ruby

# Tool to allow easy deployments on kb8
# by automating kubectl and managing versions
# TODO: 1. Parse a yaml file describing a list of kb8 directories into:
#          Deploys (the directory)
#            DeployUnits (each kb8 tier for rolling updates)
#              controller: data...
#
#       2. Discover if controller exists (and record deploy type=new/update)
#
#       3. Discover if pods exist from controller...
#          a.) Find the controller (using it's name)
#              Discover is it's running (from the pods)
#          b.) Find the selector
#          c.) Run kubectl get pods with selector
#
#       3. Resolve jsonPath variables out of templates
#       4. Tail container logs during deployments...

GET_POD = "kubectl get pods -l %1=%2 -o json"
# Create all resources:
# kubectl create -f containers/cimgt/jenkins/kb8/

require 'methadone'
require 'yaml'

YAML_VERSION_PATH = 'ContainerVersionPath'
YAML_DEPLOY_PATH = 'path'

class Kb8Deploy

  attr_accessor :deploy_units
                :container_version_path

  def initialize(deploy_file)
    @container_version_path = deploy_data[YAML_VERSION_PATH]
    @deploy_units = []

    deploy_data = YAML.load(File.read(deploy_file))
    deploy_home = File.dirname(deploy_file)
    deploy_data['Deploys'].each do | deploy_unit |
      deploy_units << Kb8DeployUnit.new(File.join(deploy_home, deploy_data[YAML_DEPLOY_PATH]),
                                        @container_version_path)
    end
  end
end

class Kb8Pod

  attr_accessor :name,
                :version,
                :image,
                :replication_controller

  def initialize(yaml_data, replication_controller)
    @replication_controller = replication_controller
    @name = yaml_data['name']
    @image = yaml_data['image']
    @version = yaml_data['image'].split(':').last
  end

  def running?(refresh=false)
    # TODO: get from controller
    @replication_controller.pod_status(@name, refresh)
  end
end

class Kb8Controller
  attr_accessor :name,
                :selector_key,
                :selector_value,
                :pods

  ROLLING_UPDATE_CMD = "| kubectl rolling-update %s-v%s -f -"
  RUNNING = 'Running'

  def initialize(yaml_data)
    @name = yaml_data['metadata']['name'].to_s
    yaml_data['spec']['selector'].attributes.each do |key, value|
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

  def deploy_type
    kb8_out = `kubectl get rc -o yaml`
    rc_data = YAML.load(kb8_out)
    rc_data.each_with_index do |item, index|
      if item.to_s == @name
        return :update
        break
      end
    end
    :create
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

class Kb8Resource
  attr_accessor :data


end

class Kb8DeployUnit

  attr_accessor :data,
                :controller

  def initialize(dir, container_version_path)

    data = {}
    # Load all files and load all data
    actual_dir = File.expand_path(dir)
    Dir["#{actual_dir}/*.yaml"].each do | file |
      kb8_data = YAML.load(File.read(file))
      case kb8_data['kind']
        when 'ReplicationController'
          if @controller
            puts "Only one controller supported per application tier"
            exit 1
          else
            @controller  = Kb8Controller.new(kb8_data)
          end
        else
          # TODO support more than one type of resource each here
          data[kb8_data['kind']] = kb8_data
      end
    end
    unless @controller
      puts "Invalid deployment unit (Missing controller) in dir:#{dir}"
      exit 1
    end
  end

  def deploy
    # Will check if all the objects exist in the cluster or not...
    @data.each do |resource|
    end

    if @controller.deploy_type == :create
    end
  end
end

class Kb8or
  include Methadone::Main
  include Methadone::CLILogging

  version     '0.0.1'
  description 'Will create OR update a kb8 application'

  main do
    Kb8Deploy.new(options[deploy_file])
  end

  on("-d deploy_file","--deploy-file","deploy_file") do |deploy_file|
    unless File.exist?(deploy_file)
      puts "Please supply a valid file name!"
      exit 1
    end
    options[:deploy_file] = deploy_file
  end

  go!
end
