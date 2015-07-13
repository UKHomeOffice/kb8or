require 'methadone'

class Context

  attr_accessor :container_version_finder,
                :deployment_home,
                :settings

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(settings, container_version_finder, deployment_home)
    debug "Creating initial context..."
    @container_version_finder = container_version_finder
    @settings = settings
    @deployment_home = deployment_home
  end

  def new(data)
    debug "Cloning new context..."
    context = Context.new(@settings.new(data),
                          @container_version_finder,
                          @deployment_home)
    context
  end
end