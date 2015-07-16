require 'methadone'

class Kb8DeployUnit

  attr_accessor :resources,
                :controller,
                :context

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(data, context)

    debug "Loading new context"
    @context = context.new(data)
    debug "Got new context"
    dir = File.join(@context.deployment_home, @context.settings.path)
    @resources = {}

    # Load all kb8 files...
    actual_dir = File.expand_path(dir)
    Dir["#{actual_dir}/*.yaml"].each do | file |
      debug "Loading kb8 file:'#{file}'..."
      kb8_data = YAML.load(File.read(file))
      case kb8_data['kind']
        when 'ReplicationController'
          if @controller
            puts 'Only one controller supported per application tier (kb8 directory)'
            exit 1
          else
            @controller  = Kb8Controller.new(kb8_data, file, @context)
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
    # TODO: Will check if all the objects exist in the cluster or not...
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
      # Skip upgrades if deployment healthy...
      if @context.settings.no_automatic_upgrade
        puts "No automatic upgrade specified for #{@controller.kinds}/#{@controller.name} skipping..."
      else
        puts "#{@controller.kinds}/#{@controller.name} will need to have a rolling updated..."
        puts "...for now, re_creating..."
        controller.re_create
        puts "...done."
      end
    else
      puts "Creating #{@controller.kinds}/#{@controller.name}..."
      @controller.create
      puts "...done."
    end
  end
end
