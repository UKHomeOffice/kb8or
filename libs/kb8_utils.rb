require 'yaml'
require 'methadone'
require_relative 'kb8_run'

class Kb8Utils
  def self.load_yaml(file_path)
    begin
      data = YAML.load(Kb8Utils.load(file_path))
    rescue Exception
      # do some logging
      raise $!, "Error parsing YAML file: #{file_path}: #{$!}", $!.backtrace
    end
    data
  end

  def self.load(file_path)
    begin
      data = File.read(file_path)
    rescue Exception
      # do some logging
      raise $!, "Error reading file: #{file_path}: #{$!}", $!.backtrace
    end
    data
  end
end