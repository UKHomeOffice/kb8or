require_relative 'kb8_utils'

class Kb8Context

  attr_accessor :cluster,
                :name,
                :namespace,
                :user

  def initialize(context_setting)
    unless context_setting.class == Hash
      raise 'Invalid context, expecting Hash'
    end
    unless context_setting['cluster'] && context_setting['namespace']
      raise 'Invalid context, expecting at least a cluster and namespace.'
    end
    @cluster = context_setting['cluster']
    @namespace = context_setting['namespace']
    if context_setting['name']
      @name = context_setting['name']
    else
      @name = @namespace
    end
    @user = context_setting['user']
  end
end