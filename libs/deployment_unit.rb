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
    path = @context.resolve_vars([@context.settings.path])
    dir = File.join(@context.deployment_home, path.pop)
    @resources = {}

    # Load all kb8 files...
    actual_dir = File.expand_path(dir)
    Dir["#{actual_dir}/*.yaml"].each do | file |
      debug "Loading kb8 file:'#{file}'..."
      kb8_data = @context.resolve_vars_in_file(file)
      debug "kb8 data:#{kb8_data}"
      case kb8_data['kind']
        when 'ReplicationController'
          if @controller
            puts 'Only one controller supported per application tier (kb8 directory)'
            exit 1
          else
            @controller  = Kb8Controller.new(kb8_data, file, @context)
          end
        else
          if kb8_data['kind'] == 'Pod'
            kb8_resource = Kb8Pod.new(kb8_data, nil, file, @context)
          else
            kb8_resource = Kb8Resource.new(kb8_data, file)
          end
          unless @resources[kb8_resource.kind]
            @resources[kb8_resource.kind] = []
          end
          @resources[kb8_resource.kind] << kb8_resource
      end
    end
    debug "NoControllerOk:#{@context.settings.no_controller_ok}"
    unless @controller
      unless @context.settings.no_controller_ok
        puts "Invalid deployment unit (Missing controller) in dir:#{dir}/*.yaml"
        exit 1
      end
    end
  end

  def create_or_recreate(resource)
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

  def deploy
    # TODO: Will check if all the objects exist in the cluster or not...
    deploy_items = []
    @resources.each do |key, resource_category|
      next if key == 'Pod'
      resource_category.each do |resource|
        deploy_items << resource
      end
    end
    if @resources.has_key?('Pod')
      deploy_items == deploy_items.concat(@resources['Pod'])
    end
    if @controller
      if @context.settings.no_automatic_upgrade && (!context.always_deploy)
        puts "No automatic upgrade specified for #{@controller.kinds}/#{@controller.name} skipping..."
      else
        deploy_items << @controller
      end
    end
    deploy_items.each do | item |
      create_or_recreate(item)
    end
  end
end
