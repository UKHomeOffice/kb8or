require_relative 'kb8_utils'

class Kb8Volumes

  attr_accessor :secrets

  def initialize(volume_data)
    unless volume_data.class == Array
      raise 'Invalid volume, expecting Volumes'
    end
    @secrets = []
    volume_data.each do |volume|
      if volume.has_key?('secret')
        @secrets << volume['secret']['secretName']
      end
    end
  end

  def uses_secret?(secret_name)
    @secrets.include?(secret_name)
  end
end