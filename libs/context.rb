require 'methadone'

class Context

  attr_accessor :container_version_finder,
                :deployment_home,
                :settings,
                :always_deploy

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(settings, container_version_finder, deployment_home, always_deploy=false)
    debug "Creating initial context..."
    @container_version_finder = container_version_finder
    @settings = settings
    @deployment_home = deployment_home
    @always_deploy = always_deploy
    debug "deployment_home=#{@deployment_home}"
    debug "container_version_finder=#{@container_version_finder}"
    debug "always_deploy=#{@always_deploy}"
  end

  def new(data)
    debug "Cloning new context..."
    context = Context.new(@settings.new(data),
                          @container_version_finder,
                          @deployment_home,
                          @always_deploy)
    context
  end
end