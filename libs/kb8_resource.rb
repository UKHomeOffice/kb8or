class Kb8Resource

  attr_accessor :data,
                :name,
                :kind,
                :kinds,
                :file

  @@resource_cache = {}

  def self.get_deployed_resources(kinds)
    kb8_out = `kubectl get #{kinds} -o yaml`
    @@resource_cache[@kinds] = YAML.load(kb8_out)
  end

  def initialize(kb8_resource_data, file)
    @file = file
    @name = kb8_resource_data['metadata']['name'].to_s
    @kind = kb8_resource_data['kind'].to_s
    @kinds = @kind + 's'
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
        return true
        break
      end
    end
    false
  end

  def create
    # Will deploy a resource that is known not to exist
    kb8_cmd = "kubectl create -f \"#{@file}\""
    `#{kb8_cmd}`
  end

  def delete
    kb8_cmd = "kubectl delete -f \"#{@file}\""
    `#{kb8_cmd}`
  end

  def re_create
    delete
    create
  end

end
