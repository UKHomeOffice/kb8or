require 'methadone'

class Kb8Deploy

  attr_accessor :deploy_units,
                :context

  YAML_DEPLOY_PATH = 'path'

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(deploy_file)

    @deploy_units = []
    deploy_home = File.dirname(deploy_file)

    # Load the file as YAML and
    debug "Loading file:#{deploy_file}..."
    deploy_data = YAML.load(File.read(deploy_file))

    settings = Kb8orSettings.new(deploy_home)
    settings.update(deploy_data)

    if settings.container_version_glob_path
      # TODO: check if version path is rooted...
      container_version_path = File.join(deploy_home, settings.container_version_glob_path)
      debug "Container version path:#{container_version_path}"
      container_version_finder = ContainerVersionFinder.new(container_version_path)
    end
    @context = Context.new(settings, container_version_finder, deploy_home)
    deploy_data['Deploys'].each do | deploy_unit |
      @deploy_units << Kb8DeployUnit.new(deploy_unit, @context)
    end
  end

  def deploy
    @deploy_units.each do | deploy_unit |
      deploy_unit.deploy
    end
  end
end
