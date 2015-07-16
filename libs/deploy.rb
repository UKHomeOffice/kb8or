require 'methadone'

class Deploy

  attr_accessor :deploy_units,
                :context

  YAML_DEPLOY_PATH = 'path'

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(deploy_file, always_deploy=false)

    @deploy_units = []
    deploy_home = File.dirname(deploy_file)

    # Load the deployment file as YAML...
    debug "Loading file:#{deploy_file}..."
    deploy_data = YAML.load(File.read(deploy_file))

    # Load default settings
    settings = Settings.new(deploy_home)
    settings.update(deploy_data)

    # Load container image version information (per image name)
    if settings.container_version_glob_path
      # TODO: check if version path is rooted...
      container_version_path = File.join(deploy_home, settings.container_version_glob_path)
      debug "Container version path:#{container_version_path}"
      container_version_finder = ContainerVersionFinder.new(container_version_path)
    end

    # Create a context object for informing each deployment...
    @context = Context.new(settings, container_version_finder, deploy_home, always_deploy)

    # Load deployment information for each 'deploy' (kb8 directory) that exists
    deploy_data['Deploys'].each do | deploy_unit |
      @deploy_units << Kb8DeployUnit.new(deploy_unit, @context)
    end
  end

  # Method to carry out the deployments
  def deploy
    @deploy_units.each do | deploy_unit |
      deploy_unit.deploy
    end
  end
end
