require_relative 'tunnel'
require_relative 'kb8_utils'
require 'uri'

class Deploy

  attr_accessor :deploy_units,
                :context,
                :tunnel

  YAML_DEPLOY_PATH = 'path'
  SSH_SOCKET = '/tmp/kb8or-ctrl-socket'

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(deploy_file,
                 always_deploy=false,
                 env_name=nil,
                 overridden_params=nil,
                 only_deploy=nil)

    @deploy_units = []
    deploy_home = File.dirname(deploy_file)

    # Load the deployment file as YAML...
    debug "Loading file:#{deploy_file}..."
    deploy_data = Kb8Utils.load_yaml(deploy_file)

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
    @context = Context.new(settings,
                           container_version_finder,
                           deploy_home,
                           always_deploy,
                           env_name,
                           overridden_params)

    # This call is crucial as it populates the environment the first time
    # NB The environment can be set as a default setting...
    unless @context.environment
      puts 'No environment set, either specify environment option (-e) or a default environment in Defaults.yaml.'
      exit 1
    end
    # Add any variables set at the start of the deploy...
    context.update_vars(deploy_data)

    # Load deployment information for each 'deploy' (kb8 directory) that exists
    deploy_data['Deploys'].each do | deploy_unit |
      @deploy_units << Kb8DeployUnit.new(deploy_unit, @context, only_deploy)
    end
  end

  # Method to carry out the deployments
  def deploy
    if @context.settings.kb8_server && @context.settings.kb8_context
      puts 'Can\'t specify both Kb8Server and Kb8Context (use Kb8Context)'
      exit 1
    end
    context_set = false
    if @context.settings.kb8_context
      Kb8Run.update_context(Kb8Context.new(@context.settings.kb8_context))
      context_set = true
    end
    if @context.settings.kb8_server
      Kb8Run.update_environment(@context.env_name, @context.settings.kb8_server)
      context_set = true
    end
    unless context_set
      puts 'Must set Kb8Context for environment'
      exit 1
    end
    @deploy_units.each do | deploy_unit |
      deploy_unit.deploy
    end
  end

  def self.print_progress
    if STDOUT.isatty
      print '.'
    else
      puts '.'
    end
    $stdout.flush
  end
end
