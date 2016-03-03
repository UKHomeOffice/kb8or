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

  def initialize(deploy_file, options)

    env_name=options[:env_name]
    @deploy_units = []
    deploy_home = File.dirname(deploy_file)

    # Load the deployment file as YAML...
    debug "Loading file:#{deploy_file}..."
    deploy_data = Kb8Utils.load_yaml(deploy_file)

    # Load default settings
    settings = Settings.new(deploy_home)
    settings.update(deploy_data)

    if options[:context_name]
      @kb8context = Kb8Context.new(options[:context_name])
      # Ensure the settings are here got the command line context:
      settings.update({ 'kb8_context' => @kb8context})
    end

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
                           options[:always_deploy],
                           env_name,
                           options[:variables])

    if @context.environment_file?
      if !@kb8context
        @kb8context = Kb8Context.new(@context.settings.kb8_context)
      end
    end

    # This call is crucial as it populates the environment the first time
    # NB The environment can be set as a default setting...
    if (!@context.environment_file?) && (!options[:context_name])
      puts 'No environment set, either specify environment option (-e) or a default environment in Defaults.yaml.'
      exit 1
    end

    unless @kb8context
      puts 'Must set Kb8Context in environment or use -c option.'
      exit 1
    end

    # Add any variables set at the start of the deploy...
    deploy_data = @context.resolve_vars(deploy_data.dup)
    @context.update_vars(deploy_data)

    # Load deployment information for each 'deploy' (kb8 directory) that exists
    deploy_data['Deploys'].each do | deploy_unit |
      @deploy_units << Kb8DeployUnit.new(deploy_unit, @context, options[:only_deploy], options[:no_diff])
    end
  end

  # Method to carry out the deployments
  def deploy
    Kb8Run.update_context(@kb8context)
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
