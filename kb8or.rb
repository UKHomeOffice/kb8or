#!/usr/bin/env ruby

# Tool to allow easy deployments on kb8
# by automating kubectl and managing versions
# TODO: Parse a yaml file describing a list of kb8 directories...
#
# Discover if pods exist...
# kubectl get pods -l name=jenkins -o json
# Create all resources:
# kubectl create -f containers/cimgt/jenkins/kb8/

require 'methadone'
require 'yaml'

class Kb8Tier

  attr_accessor :kb8_dir
                :version_file

  def initialize(data, path)
    @kb8_dir = Kb8dir.new(File.join(path, data['path']))
    @version_file = File.new(File.join(path, data['version_file'])) if data['version_file']
  end

end

class Kb8dir

  attr_accessor :data,
                :selector,
                :controller

  def initialize(dir)

    data = {}
    # Load all files and load all data
    actual_dir = File.expand_path(dir)
    Dir["#{actual_dir}/*.yaml"].each do | file |
      kb8_data = YAML.load(File.read(file))
      case kb8_data['kind']
        when 'ReplicationController'
          if @controller
            puts "Only one controller supported per app tier"
          else
            @controller  = kb8_data
            puts "Controller found:#{kb8_data['metadata']['name']}"
            puts "Container found:#{kb8_data['spec']['template']['spec']['containers'][0]['image']}"
          end
        else
          data[kb8_data['kind']] = kb8_data
      end
    end
  end
end

class Kb8or
  include Methadone::Main
  include Methadone::CLILogging

  version     '0.0.1'
  description 'Will create OR update a kb8 application'

  main do
    app_stack = YAML.load(File.read(options[:app]))
    path_name = File.dirname(options[:app])
    app_stack['apps'].each do | app |
      # Load the app path, look for containers and load
      kb8tier = Kb8Tier.new(app, path_name)
    end
  end

  on("-a app_file","--app","Application") do |app|
    unless File.exist?(app)
      puts "Please supply a valid file name!"
    end
    options[:app] = app
  end

  go!
end
