class Kb8Deploy

  attr_accessor :deploy_units,
                :container_version_finder,
                :deploy_home

  def initialize(deploy_file)

    YAML_VERSION_PATH_GLOB = 'ContainerVersionGlobPath'
    YAML_DEPLOY_PATH = 'path'

    @deploy_units = []
    deploy_home = File.dirname(deploy_file)

    # Load the file as YAML and
    deploy_data = YAML.load(File.read(deploy_file))

    # TODO: check if rooted...
    container_version_path = File.join(deploy_home, deploy_data[YAML_VERSION_PATH_GLOB])
    @container_version_finder = ContainerVersionFinder.new(container_version_path)
    deploy_data['Deploys'].each do | deploy_unit |
      deploy_units << Kb8DeployUnit.new(File.join(deploy_home, deploy_unit[YAML_DEPLOY_PATH]),
                                        container_version_finder)
    end
  end

  def deploy
    deploy_units.each do | deploy_unit |
      deploy_unit.deploy
    end
  end
end
