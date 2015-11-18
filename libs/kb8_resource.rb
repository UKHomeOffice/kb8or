require_relative 'kb8_utils'

class Kb8Resource

  attr_accessor :file,
                :kind,
                :kinds,
                :live_data,
                :name,
                :original_name,
                :resources_of_kind,
                :yaml_data

  include Methadone::Main
  include Methadone::CLILogging

  @@resource_cache = {}

  def self.get_deployed_resources(kinds)
    @@resource_cache[@kinds] = Kb8Run.get_resource_data(kinds)
  end

  def self.get_resource_from_data(kb8_data, file, context = nil)
    case kb8_data['kind']
      when 'ReplicationController'
        kb8_resource = Kb8Controller.new(kb8_data, file, context)
      when 'Pod'
        kb8_resource = Kb8Pod.new(kb8_data, nil, file, context)
      else
        kb8_resource = Kb8Resource.new(kb8_data, file)
    end
    kb8_resource
  end

  def self.create_from_name(full_name)
    name_parts = full_name.split('/')
    unless name_parts.length == 2
      raise "Invalid Kubernetes resource name:'#{full_name}. Expecting kind/name format."
    end
    kind = name_parts[0][0..-2]
    name = name_parts[1]
    kb8_resource_data = { 'apiVersion' => 'v1', 'metadata' => { 'name' => name }, 'kind' => kind }
    Kb8Resource.new(kb8_resource_data, nil)
  end

  def initialize(kb8_resource_data, file)
    @file = file
    @name = kb8_resource_data['metadata']['name'].to_s
    @kind = kb8_resource_data['kind'].to_s
    @kinds = @kind + 's'
    @yaml_data = kb8_resource_data
    # This holds whilst we always use the file data...
    @original_name = @name.dup
  end

  def data(refresh=false)
    unless @live_data
      refresh = true
    end
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
      @resources_of_kind = Kb8Resource.get_deployed_resources(@kinds)
    else
      @resources_of_kind = @@resource_cache[@kinds]
    end

    # Check if the item exists
    @resources_of_kind['items'].each do |item|
      if item['metadata'] && item['metadata'].has_key?('name') && item['metadata']['name'] == @name
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

  def update
    case @kind
      when 'Secret','ServiceAccount'
        replace
      else
        # TODO: add error handling to use appropriate update type...
        # Only safe way to know for sure...  ...for now?
        delete
        create
    end
  end

  def original_full_name
    "#{@kinds}/#{@original_name}"
  end
end
