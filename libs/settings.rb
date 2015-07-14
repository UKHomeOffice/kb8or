require 'yaml'
require 'methadone'

class Settings

  # TODO: Split this out into separate expected schema settings files...?

  FILE_DEFAULTS = 'defaults.yaml'

  attr_accessor :container_version_glob_path,
                :defaults,
                :defaults_set,
                :private_registry,
                :use_private_registry,
                :path

  include Methadone::Main
  include Methadone::CLILogging

  def underscore(camel_yaml_key)
    camel_yaml_key.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      downcase
  end

  def initialize(deploy_home)
    defaults_file = File.join(deploy_home, FILE_DEFAULTS)
    if File.exist?(defaults_file)
      debug "Loading settings"
      @defaults = YAML.load(File.open(defaults_file))
    end
  end

  def set_defaults_once
    unless @defaults_set
      debug 'Setting defaults...'
      set_attribs_from_data(@defaults) if @defaults
      defaults_set = true
    end
  end

  def update(data)
    set_defaults_once unless @defaults_set
    set_attribs_from_data(data)
  end

  def set_attribs_from_data(data)
    data.each_pair do | key, value |
      unless key == 'defaults' || key == 'defaults_set'
        actual_key = underscore(key)
        debug "Data to set context includes:#{actual_key}"
        if self.respond_to? "#{actual_key}="
          debug "Setting #{actual_key}= (from #{key} in yaml) to #{value}"
          self.__send__("#{actual_key}=", value)
        end
      end
    end
  end

  def new(data)
    debug "Ready to clone:#{self.respond_to?('dup')}"
    new_context = self.dup
    # Not sure if dup is working here...
    # new_context.defaults_set = true
    new_context.update(data)
    new_context
  end
end