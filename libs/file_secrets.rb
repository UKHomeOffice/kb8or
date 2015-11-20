require_relative 'kb8_resource'
require_relative 'kb8_utils'

class FileSecrets

  attr_accessor :name,
                :secrets,
                :path

  class Secret

    attr_accessor :name,
                  :base64_data

    def initialize(file)
      @base64_data = Base64.encode64(Kb8Utils.load(file))
      @name = File.basename(file)
    end
  end

  def self.create_from_context(context)
    unless context.settings.file_secrets.has_key?('name')
      raise "Invalid deployment unit (Missing name attribute) for FileSecrets setting for path:#{context.deployment_home}"
    end
    unless context.settings.file_secrets.has_key?('path')
      raise "Invalid deployment unit (Missing path attribute) for FileSecrets setting for path:#{context.deployment_home}"
    end

    name = context.settings.file_secrets['name']
    path = File.join(context.deployment_home, context.settings.file_secrets['path'])

    FileSecrets.new(path, name, context).create_secret_resource()
  end

  def initialize(path, name, context)
    @path = File.expand_path(context.resolve_vars(path))
    @name = name
    @context = context
    @secrets = []
    unless Dir.exist?(@path)
      raise "Invalid deployment unit for FileSecrets setting, path not found:#{@path}"
    end
    Dir[@path].each do | file |
      @secrets << Secret.new(file)
    end
  end

  def create_secret_resource
    resource_data = Kb8Resource.resource_data_from_name("Secrets/#{@name}")
    resource_data['type'] = 'Opaque'
    secret_data = {}
    @secrets.each do | secret |
      secret_data[secret.name] = secret.base64_data
    end
    resource_data['data'] = secret_data
    Kb8Resource.new(resource_data)
  end

end