#!/usr/bin/env ruby

# Tool to allow easy deployments on kb8
# by automating kubectl and managing versions

require 'methadone'
require 'yaml'
require 'pathname'

KB8_HOME = File.dirname(Pathname.new(__FILE__).realdirpath)
Dir.glob(File.join(KB8_HOME, 'libs/*.rb')) { |f| require f }

class Kb8or
  include Methadone::Main
  include Methadone::CLILogging

  version     File.read(File.join(KB8_HOME, 'version'))
  description 'Will create OR update a kb8 application in a re-runnable way'

  arg :deploy_file

  main do |deploy_file|
    unless File.exist?(deploy_file)
      puts "Please supply a valid file name! (#{deploy_file})"
      exit 1
    end

    deploy = Deploy.new(deploy_file,
                        options[:always_deploy],
                        options[:env_name],
                        options[:tunnel],
                        options[:tunnel_options],
                        options[:variables])
    deploy.deploy
  end

  opts.on("-a","--always-deploy","Ignore NoAutomaticUpgrade deployment setting") do
    options[:always_deploy] = true
  end

  opts.on("-e ENVIRONMENT","--environment","Specify the environment") do |env_name|
    options[:env_name] = env_name
  end

  opts.on("-s VARIABLES", "--set-variables", "A comma seperated list of variable=value") do |variables|
    unless /^.+=[^,]+(,.+=[^,]+)*/ =~ variables
      raise "Variables does not match format like ALPHA=a,BETA=b"
    end

    variable_hash = {}

    variables.split(',').each do |variable|
      split_variable = variable.split('=', 2)

      variable_hash[split_variable[0]] = split_variable[1]
    end

    options[:variables] = variable_hash
  end

  opts.on('-t TUNNEL',
          '--tunnel',
          'An ssh server to tunnel through') do |tunnel|
    options[:tunnel] = tunnel
  end

  opts.on('-o SSH_OPTIONS',
          '--tunnel-options',
          'Any ssh options e.g. "-i ~/.ssh/id_project_key" (NB Quotes)') do |tunnel_opts|
    options[:tunnel_options] = tunnel_opts
  end

  use_log_level_option
  go!
end
