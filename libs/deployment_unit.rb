require 'methadone'

class Kb8DeployUnit

  attr_accessor :context,
                :only_deploy,
                :resources

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(data, context, only_deploy=nil)
    @only_deploy = only_deploy
    debug 'Loading new context'
    @context = context.new(data)
    debug 'Got new context'
    path = @context.resolve_vars([@context.settings.path])
    dir = File.join(@context.deployment_home, path.pop)
    @resources = {}

    # Load all kb8 files...
    actual_dir = File.expand_path(dir)
    Dir["#{actual_dir}/*.yaml"].each do | file |
      debug "Loading kb8 file:'#{file}'..."
      kb8_data = @context.resolve_vars_in_file(file)
      debug "kb8 data:#{kb8_data}"

      new_items = nil
      if @context.settings.multi_template
        multi_template = MultiTemplate.new(kb8_data, @context, file, dir)
        new_items = multi_template.items if multi_template.valid_data?
      end
      unless new_items
        new_items = []
        new_items << Kb8Resource.get_resource_from_data(kb8_data, file, @context)
      end
      new_items.each do | kb8_resource |
        unless @resources[kb8_resource.kind]
          @resources[kb8_resource.kind] = []
        end
        @resources[kb8_resource.kind] << kb8_resource
      end
    end
    debug "NoControllerOk:#{@context.settings.no_controller_ok}"
    unless @resources.has_key?('ReplicationController')
      unless @context.settings.no_controller_ok
        puts "Invalid deployment unit (Missing controller) in dir:#{dir}/*.yaml"
        exit 1
      end
    end
  end

  def create_or_update(resource)
    if resource.exist?
      if resource.up_to_date?
        puts "No Change for #{resource.kinds}/#{resource.name}, Skipping."
        return true
      end
      puts "Updating #{resource.kinds}/#{resource.name}..."
      update_ok = true
      if resource.kinds == 'Services'
        unless context.settings.recreate_services
          update_ok = false
          puts '...Not re-creating service, Use setting RecreateServices to override.'
        end
      end
      resource.update if update_ok
      puts '...done.'
    else
      puts "Creating #{resource.kinds}/#{resource.name}..."
      resource.create
      puts '...done.'
    end
  end

  def deploy
    if @context.settings.delete_items
      @context.settings.delete_items.each do |resource_name|
        resource = Kb8Resource.create_from_name(resource_name)
        if resource.exist?
          puts "Deleting #{resource.kinds}/#{resource.name}..."
          resource.delete()
        end
      end
    end

    # Order resources before deploying them...
    deploy_items = []
    @resources.each do |key, resource_category|
      next if key == 'Pod'
      next if key == 'ReplicationController'
      resource_category.each do |resource|
        deploy_items << resource
      end
    end
    if @resources.has_key?('Pod')
      deploy_items == deploy_items.concat(@resources['Pod'])
    end
    if @resources.has_key?('ReplicationController')
      possible_items = @resources['ReplicationController']
      possible_items.each do | item |
        if item.exist? && item.context.settings.no_automatic_upgrade && (!@context.always_deploy)
          puts "No automatic upgrade specified for #{item.kinds}/#{item.name} skipping..."
        else
          deploy_items << item
        end
      end
    end
    deploy_items.each do | item |
      deploy = (@only_deploy.nil? || @only_deploy.to_a.include?(item.original_full_name))
      if deploy
        create_or_update(item)
      else
        puts "Skipping resource (-d):#{item.original_full_name}"
      end
    end
  end
end
