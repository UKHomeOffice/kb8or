require 'methadone'

class Kb8Run

  include Methadone::Main
  include Methadone::CLILogging

  API_VERSION = 'v1'
  CMD_KUBECTL = 'kubectl'
  CMD_ROLLING_UPDATE = "#{CMD_KUBECTL} --api-version=\"#{API_VERSION}\" rolling-update %s-v%s -f -"
  CMD_CREATE = "#{CMD_KUBECTL} create -f -"
  CMD_UPDATE = "#{CMD_KUBECTL} update -f -"
  CMD_DELETE = "#{CMD_KUBECTL} delete %s/%s"
  CMD_GET_POD_LOGS = "#{CMD_KUBECTL} logs %s"
  CMD_GET_POD = "#{CMD_KUBECTL} --api-version=\"#{API_VERSION}\" get pods -l %s=%s -o yaml"
  CMD_GET_EVENTS = "#{CMD_KUBECTL} --api-version=\"#{API_VERSION}\" get events -o yaml"
  CMD_GET_RESOURCE = "#{CMD_KUBECTL} --api-version=\"#{API_VERSION}\" get %s -o yaml"
  CMD_DELETE_PODS = "#{CMD_KUBECTL} delete pods -l %s=%s"
  CMD_CONFIG_CLUSTER = "#{CMD_KUBECTL} config set-cluster %s --server=%s"
  CMD_CONFIG_CONTEXT = "#{CMD_KUBECTL} config set-context kb8or-context --cluster=%s --namespace=%s"
  CMD_CONFIG_DEFAULT = "#{CMD_KUBECTL} config use-context kb8or-context"

  class KubeCtlError < StandardError

    attr_accessor :subprocess,
                  :output

    RETRY_COUNT = 3
    ERROR_IO_TIMEOUT = /error: couldn't read version from server.*i\/o timeout/
    RETRY_ERRS = [ERROR_IO_TIMEOUT]

    def initialize(subprocess, output)
      @subprocess = subprocess
      @output = output
    end

    def enough_already?(errors)
      # First work out if the error is retryable...
      retryable = false
      RETRY_ERRS.each do | err_regexp |
        if err_regexp =~ @output
          retryable = true
          break
        end
      end
      # For non-retryable errors - we've always had enough!
      return true unless retryable
      error_count = 0
      errors.each do |error|
        error_count = error_count +1 if error.message == @output
      end
      (error_count >= RETRY_ERRS)
    end
  end

  def self.run(cmd, capture=false, term_output=true, input=nil)

    # pipe if specifying input
    if input
      mode = 'w+'
    else
      mode = 'r'
    end

    errors = []
    ok = false
    until ok
      output = ''
      # Run process and capture output if required...
      debug "Running:'#{cmd}', '#{mode}'"
      pid = nil
      IO.popen(cmd, mode) do |subprocess|
        pid = subprocess.pid
        if input
          debug "#{input}"
          subprocess.write(input)
          subprocess.close_write
        end
        subprocess.read.split("\n").each do |line|
          puts line if term_output
          output << "#{line}\n"  if capture
        end
        subprocess.close
        if $?.success?
          ok = true
        else
          if cmd.start_with?(CMD_KUBECTL)
            error = KubeCtlError.new(subprocess, output)
            raise error if error.enough_already?(errors)
            errors << error
          else
            raise "Error running #{cmd}, exit code '#{$?.to_i}':\n#{output}"
          end
        end
      end
    end
    if capture
      return output
    end
    pid
  end

  def self.update_environment(env_name, server)
    # Add the config commands (read from the environments)
    cmd = CMD_CONFIG_CLUSTER % [env_name, server]
    Kb8Run.run(cmd, false, true)
    # Ensure a namespace compatible name...
    cmd = CMD_CONFIG_CONTEXT % [env_name, env_name]
    Kb8Run.run(cmd, false, true)
    Kb8Run.run(CMD_CONFIG_DEFAULT, false, true)
  end

  def self.create(yaml_data)
    Kb8Run.run(CMD_CREATE, true, true, yaml_data.to_s)
  end

  def self.update(yaml_data)
    Kb8Run.run(CMD_UPDATE, true, true, yaml_data.to_s)
  end

  def self.delete_pods(selector_key, selector_value)
    debug "Deleting pods matching selector:#{selector_key}=#{selector_value}"
    cmd = CMD_DELETE_PODS % [selector_key, selector_value]
    Kb8Run.run(cmd, false, true)
  end

  def self.delete_resource(type, name)
    debug "Deleting resource:#{type}/#{name}"
    cmd = CMD_DELETE % [type, name]
    Kb8Run.run(cmd, false, true)
  end

  def self.get_resource_data(type)
    debug "Getting resource data:#{type}"
    cmd = CMD_GET_RESOURCE % type
    kb8_out = Kb8Run.run(cmd, true, false)
    yaml = YAML.load(kb8_out)
    yaml
  end

  def self.get_pod_status(selector_key, selector_value)
    debug "Get pods with selector '#{selector_key}' with value:'#{selector_value}'"
    cmd = CMD_GET_POD % [selector_key, selector_value]
    kb8_out = Kb8Run.run(cmd, true, false)
    debug "Loading YAML data from kubectl:\n#{kb8_out}"
    yaml = YAML.load(kb8_out)
    debug "YAML loaded..."
    yaml
  end

  def self.get_pod_logs(pod_name)
    unless pod_name
      raise "Error - expecting a valid string for pod_name"
    end
    debug "Getting logs from kubectl:\n#{pod_name}"
    cmd = CMD_GET_POD_LOGS % pod_name
    kb8_out = Kb8Run.run(cmd)
    kb8_out
  end

  # Will get all events for a pod
  def self.get_pod_events(pod_name)
    unless pod_name
      raise "Error - expecting a valid string for pod_name"
    end
    kb8_out = Kb8Run.run(CMD_GET_EVENTS, true, false)
    yaml = YAML.load(kb8_out)
    relevant_events = []
    # TODO: work out filters (selectors set by rc's don't work here!!!)
    yaml['items'].each do |event|
      event_name = event['involvedObject']['name'].to_s
      if event_name == pod_name.to_s
        relevant_events << event
      end
    end
    events_by_time = relevant_events.sort { |a, b| a['lastTimestamp'] <=> b['lastTimestamp'] }
    events_by_time
  end
end