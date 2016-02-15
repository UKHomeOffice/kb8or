require_relative 'kb8_utils'
require 'digest'
require_relative 'file_secrets'

class Kb8Resource

  include Methadone::Main
  include Methadone::CLILogging

  KB8_MD5_KEY = 'kb8_md5'
  RESOURCE_POD = 'Pod'
  RESOURCE_RC = 'ReplicationController'
  RESOURCE_NAMESPACE = 'Namespace'
  KB8_DIRTY_KEY = 'kb8_failing'

  attr_accessor :file,
                :kind,
                :kinds,
                :live_data,
                :md5,
                :name,
                :namespace,
                :original_name,
                :resources_of_kind,
                :yaml_data

  def self.get_resource_from_data(kb8_data, file, context = nil)
    case kb8_data['kind']
      when RESOURCE_RC
        kb8_resource = Kb8Controller.new(kb8_data, file, context)
      when RESOURCE_POD
        kb8_resource = Kb8Pod.new(kb8_data, nil, file, context)
      else
        kb8_resource = Kb8Resource.new(kb8_data, file)
    end
    kb8_resource
  end

  def self.resource_data_from_name(full_name)
    name_parts = full_name.split('/')
    unless name_parts.length == 2
      raise "Invalid Kubernetes resource name:'#{full_name}. Expecting kind/name format."
    end
    kind = name_parts[0][0..-2]
    name = name_parts[1]
    { 'apiVersion' => Kb8Run::API_VERSION, 'metadata' => { 'name' => name }, 'kind' => kind }
  end

  def self.create_from_name(full_name)
    kb8_resource_data = Kb8Resource.resource_data_from_name(full_name)
    Kb8Resource.new(kb8_resource_data, nil)
  end

  def initialize(kb8_resource_data, file=nil)
    @resource_cache = {}
    @file = file
    @name = kb8_resource_data['metadata']['name'].to_s
    @kind = kb8_resource_data['kind'].to_s
    if kb8_resource_data['metadata']['namespace']
      @namespace =  kb8_resource_data['metadata']['namespace']
    end
    @kinds = @kind + 's'
    @yaml_data = kb8_resource_data
    # This holds whilst we always use the file data...
    @original_name = @name.dup
    update_md5
  end

  def update_md5
    @md5 = Digest::MD5.hexdigest(YAML.dump(@yaml_data))
    unless @yaml_data['metadata']['labels']
      @yaml_data['metadata']['labels'] = {}
    end
    @yaml_data['metadata']['labels'][KB8_MD5_KEY] = @md5
  end

  def mark_dirty
    # We'll ensure this resource will get replaced at next deploy...
    patch = { 'metadata' => {'labels' => { KB8_MD5_KEY => '', KB8_DIRTY_KEY => 'TRUE'}}}
    Kb8Run.patch(patch, @kind, @name)
    refresh_data
  end

  def is_dirty?
    if exist?
      data['metadata'] && data['metadata'].has_key?('labels') &&
          data['metadata']['labels'].has_key?(KB8_DIRTY_KEY)
    else
      false
    end
  end

  def refresh_data
    exist?(true)
  end

  def data(refresh=false)
    unless @live_data
      refresh = true
    end
    if exist?(refresh)
      @live_data
    end
  end

  def namespace_defined?
    if @namespace
      true
    else
      false
    end
  end

  def exist?(refresh=false)

    exists = false
    # Check the cache if required
    unless @resource_cache.has_key?(@kinds)
      refresh = true
    end
    if refresh
      if @kind == RESOURCE_NAMESPACE
        @resource_cache[@kinds] = Kb8Run.get_resource_data(@kinds, true)
      elsif namespace_defined?
        @resource_cache[@kinds] = Kb8Run.get_resource_data(@kinds, false, @namespace)
      else
        @resource_cache[@kinds] = Kb8Run.get_resource_data(@kinds, false)
      end
    end
    @resources_of_kind = @resource_cache[@kinds]

    # Check if the item exists
    @resources_of_kind['items'].each do |item|
      if item['metadata'] && item['metadata'].has_key?('name') && item['metadata']['name'] == @name
        if namespace_match?(item)
          @live_data = item
          exists = true
          break
        end
      end
    end
    exists
  end

  def namespace_match?(item)
    match = false
    if @namespace
      if item['metadata'] && item['metadata'].has_key?('namespace') && item['metadata']['namespace'] == @namespace
        match = true
      end
    else
      match = true
    end
    match
  end

  def up_to_date?
    # Check for the existence of the MD5 hash and compare...
    if exist?
      @live_data['metadata'].has_key?('labels') &&
          @live_data['metadata']['labels'].has_key?(KB8_MD5_KEY) &&
          @live_data['metadata']['labels'][KB8_MD5_KEY] == @md5
    else
      false
    end
  end

  def uses_any_secret?(secrets)
    secrets.each do |secret|
      return true if uses_secret?(secret)
    end
    false
  end

  def uses_secret?(secret_name)
    if @volumes
      return @volumes.uses_secret?(secret_name)
    end
    false
  end

  def create
    # Will deploy a resource that is known not to exist
    yaml_string = YAML.dump(yaml_data)
    Kb8Run.create(yaml_string)
  end

  def delete
    Kb8Run.delete_resource(@kind, @name, @namespace)
  end

  def replace
    yaml_string = YAML.dump(yaml_data)
    Kb8Run.replace(yaml_string)
  end

  def update
    case @kind
      when 'Secret','ServiceAccount','Namespace','LimitRange'
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
