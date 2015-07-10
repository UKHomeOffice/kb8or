class Kb8Pod

  attr_accessor :name,
                :version,
                :image_name,
                :replication_controller

  REGISTRY = '(\S+:[\d]+|\S+\.\S+)'
  VERSION = '(:.*)'
  IMAGE = '(.*)'
  NAMESPACE = '(^\w+)'

  def initialize(yaml_data, replication_controller)
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
    image
  end

  def set_registry(registry)
    unless @registry
      raise 'Can only replace images with existing registry server specified'
    end
    unless registry =~ /#{REGISTRY}/
      raise "Invalid registry specified, expecting IP, DNS or port e.g. #{REGISTRY}"
    end
    @registry = registry
  end

  def set_version(version)
    # TODO: check valid version regexp
    @version = version
  end

  def running?(refresh=false)
    @replication_controller.pod_status(@name, refresh)
  end
end
