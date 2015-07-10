class Kb8DeployUnit

  attr_accessor :resources,
                :controller,
                :dir

  def initialize(dir, container_version_finder)

    @dir = dir
    @resources = {}

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
            @controller  = Kb8Controller.new(kb8_data, file, container_version_finder)
          end
        else
          kb8_resource = Kb8Resource.new(kb8_data, file)
          unless @resources[kb8_resource.kind]
            @resources[kb8_resource.kind] = []
          end
          @resources[kb8_resource.kind] << kb8_resource
      end
    end
    unless @controller
      puts "Invalid deployment unit (Missing controller) in dir:#{dir}"
      exit 1
    end
  end

  def deploy
    # Will check if all the objects exist in the cluster or not...
    @resources.each do |key, resource_category|
      resource_category.each do |resource|
        if resource.exist?
          puts "Recreating #{resource.kinds}/#{resource.name}..."
          resource.re_create
          puts "...done."
        else
          puts "Creating #{resource.kinds}/#{resource.name}..."
          resource.create
          puts "...done."
        end
      end
    end

    if @controller.exist?
      puts "#{@controller.kinds}/#{@controller.name} will need to have a rolling updated..."
      puts "...for now, re_creating..."
      controller.re_create
      puts "...done."
    else
      puts "Creating #{@controller.kinds}/#{@controller.name}..."
      @controller.create
      puts "...done."
    end
  end
end
