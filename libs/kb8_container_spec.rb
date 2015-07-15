require 'methadone'

class Kb8ContainerSpec

  include Methadone::Main
  include Methadone::CLILogging

  REGISTRY = '(\S+:[\d]+|\S+\.\S+)'
  VERSION = '(:.*)'
  IMAGE = '([a-z0-9_].+)'
  NAMESPACE = '([a-zA-Z0-9-\_]+)'

  attr_accessor :name,
                :version,
                :image_name,
                :replication_controller,
                :yaml_data

  def initialize(yaml_data, replication_controller)
    @yaml_data = yaml_data
    @replication_controller = replication_controller
    @name = yaml_data['name']
    case yaml_data['image']
      when /#{REGISTRY}\/#{IMAGE}#{VERSION}/
        # registry with image and version:
        @registry = $1
        @image_name = $2
        @version = $3
      when /#{REGISTRY}\/#{IMAGE}/
        # registry with image and NO version:
        @registry = $1
        @image_name = $2
      when /#{NAMESPACE}\/#{IMAGE}/
        # namespace with NO version
        @namespace = $1
        @image_name = $2
      when /#{NAMESPACE}\/#{IMAGE}#{VERSION}/
        @namespace = $1
        @image_name = $2
        @version = $3
      when /#{IMAGE}#{VERSION}/
        @image_name = $1
        @version = $2
      when /#{IMAGE}/
        @image_name = $1
      else
        raise "Invalid image tag in pod #{@name}: #{yaml_data['image']}"
    end
  end

  def image
    # Put back the image name...
    image = ''
    if @registry
      image = @registry + '/'
    end
    if @namespace
      image = @namespace + '/'
    end
    image = "#{image}#{@image_name}"
    image = "#{image}:#{@version}" if @version
    @yaml_data['image'] = image
    image
  end

  def set_registry(registry)
    unless @registry
      raise 'Can only replace images with existing registry server specified'
    end
    unless registry =~ /#{REGISTRY}/
      raise "Invalid registry specified, expecting IP, DNS or port e.g. #{REGISTRY}"
    end
    debug "Setting registry of pod '#{name}' to '#{registry}'"
    @registry = registry
    to_yaml
    true
  end

  def set_version(version)
    debug "Setting version of pod '#{name}' to '#{version}'"
    # TODO: check valid version regexp
    @version = version
    to_yaml
    true
  end

  def to_yaml
    # Update any data and return the data
    image
    @yaml_data
  end
end
