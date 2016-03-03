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

  VERSION_STRING = File.read(File.join(KB8_HOME, 'version'))
  KB8_BANNER = 'Kb8or:v%s'

  version     VERSION_STRING
  description 'Will create OR update a kb8 application in a re-runnable way'

  arg :deploy_file

  main do |deploy_file|
    unless File.exist?(deploy_file)
      puts "Please supply a valid file name! (#{deploy_file})"
      exit 1
    end

    deploy = Deploy.new(deploy_file, options)

    begin
      puts KB8_BANNER % VERSION_STRING
      if options[:noop]
        puts 'Noop, Deployment files parse OK.'
      else
        deploy.deploy unless options[:close_tunnel]
      end
    rescue TypeError, NameError => e
      puts "Kb8or bug:#{e.message}\n#{e.backtrace.inspect}"
      raise
    end
  end

  opts.on('-a','--always-deploy','Ignore NoAutomaticUpgrade deployment setting') do
    options[:always_deploy] = true
  end

  opts.on('-f', '--no-diff', 'Do not diff resources (i.e. update identical resources') do
    options[:no_diff] = true
  end

  opts.on('-e ENVIRONMENT','--environment','Specify the environment') do |env_name|
    options[:env_name] = env_name
  end

  opts.on('-c CONTEXT','--context','Specify the context') do |context_name|
    options[:context_name] = context_name
  end

  opts.on('-s VARIABLES', '--set-variables', 'A comma separated list of variable=value') do |variables|
    unless /^.+=[^,]+(,.+=[^,]+)*/ =~ variables
      raise 'Variables does not match format like ALPHA=a,BETA=b'
    end

    variable_hash = {}

    variables.split(',').each do |variable|
      split_variable = variable.split('=', 2)

      variable_hash[split_variable[0]] = split_variable[1]
    end

    options[:variables] = variable_hash
  end

  opts.on('-n', '--noop', 'Just load deploy files (or create a tunnel)') do
    options[:noop] = true
  end

  opts.on('-d DEPLOY_ONLY_CSV',
          '--deploy-only-list',
          'Limit deployment to only the resources listed (csv) e.g. ResourceControllers/mycontroller') do | only_deploy |
    options[:only_deploy] = only_deploy.split(',')
  end

  use_log_level_option
  go!
end
