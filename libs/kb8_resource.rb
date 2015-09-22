require_relative 'kb8_utils'

class Kb8Resource

  attr_accessor :live_data,
                :name,
                :kind,
                :kinds,
                :file,
                :yaml_data

  include Methadone::Main
  include Methadone::CLILogging

  @@resource_cache = {}

  def self.get_deployed_resources(kinds)
    @@resource_cache[@kinds] = Kb8Run.get_resource_data(kinds)
  end

  def initialize(kb8_resource_data, file)
    @file = file
    @name = kb8_resource_data['metadata']['name'].to_s
    @kind = kb8_resource_data['kind'].to_s
    @kinds = @kind + 's'
    @yaml_data = kb8_resource_data
  end

  def data(refresh=false)
    if exist?(refresh)
      @live_data
    end
  end

  def exist?(refresh=false)

    # Check the cache if required
    unless @@resource_cache.has_key?(@kinds)
      refresh = true
    end
    if refresh
      resources_of_kind = Kb8Resource.get_deployed_resources(@kinds)
    else
      resources_of_kind = @@resource_cache[@kinds]
    end

    # Check if the item exists
    resources_of_kind['items'].each do |item|
      if item['metadata']['name'] == @name
        @live_data = item
        return true
        break
      end
    end
    false
  end

  def create
    # Will deploy a resource that is known not to exist
    yaml_string = YAML.dump(yaml_data)
    Kb8Run.create(yaml_string)
  end


  def delete
    Kb8Run.delete_resource(@kind, @name)
  end

  def replace
    yaml_string = YAML.dump(yaml_data)
    Kb8Run.replace(yaml_string)
  end

  def re_create
    delete
    create
  end

end
