require 'yaml'
require 'methadone'
require_relative 'kb8_run'

class Kb8Utils
  def self.load_yaml(file_path)
    begin
      data = YAML.load(File.read(file_path))
    rescue Exception => e
      # do some logging
      raise $!, "Error parsing YAML file: #{file_path}: #{$!}", $!.backtrace
    end
    data
  end
end