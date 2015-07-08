class Kb8Deploy

  attr_accessor :deploy_units
  :container_version_path

  def initialize(deploy_file)

    @deploy_units = []
    deploy_home = File.dirname(deploy_file)

    # Load the file as YAML and
    deploy_data = YAML.load(File.read(deploy_file))
    @container_version_path = deploy_data[YAML_VERSION_PATH]
    deploy_data['Deploys'].each do | deploy_unit |
      deploy_units << Kb8DeployUnit.new(File.join(deploy_home, deploy_unit[YAML_DEPLOY_PATH]),
                                        @container_version_path)
    end
  end

  def deploy
    deploy_units.each do | deploy_unit |
      deploy_unit.deploy
    end
  end
end
