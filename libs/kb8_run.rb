require 'methadone'
require 'open3'
require 'json'
require_relative 'runner'
require_relative 'safe_runner'

class Kb8Run

  include Methadone::Main
  include Methadone::CLILogging

  API_VERSION = 'v1'
  MISSING_DATA_RETRIES = 3
  CMD_KUBECTL = 'kubectl'
  CMD_ROLLING_UPDATE = "#{CMD_KUBECTL} --api-version=\"#{API_VERSION}\" rolling-update %s -f -"
  CMD_CREATE = "#{CMD_KUBECTL} create -f -"
  CMD_REPLACE = "#{CMD_KUBECTL} replace -f -"
  CMD_DELETE = "#{CMD_KUBECTL} delete %s/%s"
  CMD_GET_POD_LOGS = "#{CMD_KUBECTL} logs %s %s"
  CMD_GET_POD = "#{CMD_KUBECTL} --api-version=\"#{API_VERSION}\" get pods -l %s -o yaml"
  CMD_GET_EVENTS = "#{CMD_KUBECTL} --api-version=\"#{API_VERSION}\" get events -o yaml"
  CMD_GET_RESOURCE = "#{CMD_KUBECTL} --api-version=\"#{API_VERSION}\" get %s -o yaml"
  CMD_DELETE_PODS = "#{CMD_KUBECTL} delete pods -l %s"
  CMD_CONFIG_CLUSTER = "#{CMD_KUBECTL} config set-cluster %s --server=%s"
  CMD_CONFIG_CONTEXT = "#{CMD_KUBECTL} config set-context kb8or-context --cluster=%s --namespace=%s"
  CMD_CONFIG_DEFAULT = "#{CMD_KUBECTL} config use-context kb8or-context"

  class KubeCtlError < StandardError

    attr_accessor :output,
                  :message,
                  :retryable

    RETRY_COUNT = 3
    RETRY_BACK_OFF = 3
    ERROR_IO_TIMEOUT = /error: couldn't read version from server.*i\/o timeout/
    ERROR_IO_REFUSED = /error: couldn't read version from server.*: connection refused/
    ERROR_IO_TLS_TIMEOUT = /error: couldn't read version from server.*: TLS handshake timeout/
    RETRY_ERRS = [ERROR_IO_REFUSED, ERROR_IO_TIMEOUT, ERROR_IO_TLS_TIMEOUT]

    def initialize(status, cmd, output, input)
      @output = output
      @message = ''

      # Work out if the error is retryable...
      @retryable = false
      RETRY_ERRS.each do | err_regexp |
        if err_regexp =~ @output
          @retryable = true
          break
        end
      end
      if input
        @message = "Error when using stdin:\n#{input}\n"
      end
      @message = "#{@message}Error (exit code:'#{status.exitstatus.to_i}') running '#{cmd}':\n#{output}\n"
      @message = "#{@message}Error (Tried #{RETRY_COUNT} times) #{@message}" if @retryable
    end

    def enough_already?(errors)
      # For non-retryable errors - we've always had enough!
      return true unless retryable
      error_count = 0
      errors.each do |error|
        if error == self
          error_count = error_count + 1
          sleep RETRY_BACK_OFF
        end
      end
      (error_count >= RETRY_COUNT)
    end

    def == (other_object)
      (self.output == other_object.output)
    end
  end

  def self.run(cmd, capture=false, term_output=true, input=nil, safe=true)

    errors = []
    ok = false
    until ok
      # Run process and capture output if required...
      debug "Running:'#{cmd}'"
      pid = nil
      if safe
        runner = SafeRunner.new(cmd, term_output, input)
      else
        # Something wrong with thread handling - no problem when not parsing returned text
        runner = Runner.new(cmd, term_output, input)
      end

      pid = runner.status
      if runner.status.success?
        if capture
          return runner.stdout
        end
        ok = true
      else
        if cmd.start_with?(CMD_KUBECTL)
          error = KubeCtlError.new(runner.status, cmd, runner.stderr, input)
          raise error if error.enough_already?(errors)
          errors << error
        else
          raise "Error running #{cmd}, exit code '#{runner.status.exitstatus}':\n#{runner.stderr}"
        end
      end
    end
    pid
  end

  def self.get_yaml_data(cmd)
    retries = 0
    yaml = nil
    until yaml || retries >= MISSING_DATA_RETRIES
      retries = retries + 1
      kb8_out = Kb8Run.run(cmd, true, false)
      debug "Loading YAML data from kubectl:\n#{kb8_out}"
      if kb8_out
        yaml = YAML.load(kb8_out)
        debug 'YAML loaded...'
      end
    end
    unless yaml
      raise "Cmd:#{cmd} failed to return any data for loading into YAML after #{MISSING_DATA_RETRIES} tries!"
    end
    yaml
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
    debug "Creating with:'#{yaml_data.to_s}'"
    Kb8Run.run(CMD_CREATE, true, true, yaml_data.to_s)
  end

  def self.replace(yaml_data)
    debug "Replacing with:'#{yaml_data.to_s}'"
    Kb8Run.run(CMD_REPLACE, true, true, yaml_data.to_s)
  end

  def self.rolling_update(yaml_data, old_controller)
    debug "Rolling update with:'#{yaml_data.to_s}'"
    cmd = CMD_ROLLING_UPDATE % old_controller
    Kb8Run.run(cmd, true, true, yaml_data.to_s, false)
  end

  def self.delete_pods(selector_string)
    debug "Deleting pods matching selectors:#{selector_string}"
    cmd = CMD_DELETE_PODS % [selector_string]
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
    yaml_data = Kb8Run.get_yaml_data(cmd)
    yaml_data
  end

  def self.get_pod_status(selector_string)
    # Allow a few retires here, to cope with no data:
    debug "Get pods with selectors: '#{selector_string}'"
    cmd = CMD_GET_POD % [selector_string]
    yaml_data = Kb8Run.get_yaml_data(cmd)
    yaml_data
  end

  def self.get_pod_logs(pod_name, container_name=nil)
    unless pod_name
      raise "Error - expecting a valid string for pod_name"
    end
    debug "Getting logs from kubectl:\n#{pod_name}"
    options = [pod_name]
    if container_name
      options << " -c #{container_name}"
    end
    cmd = CMD_GET_POD_LOGS % options
    kb8_out = Kb8Run.run(cmd, true, false)
    kb8_out
  end

  # Will get all events for a pod
  def self.get_pod_events(pod_name)
    unless pod_name
      raise 'Error - expecting a valid string for pod_name'
    end
    yaml = Kb8Run.get_yaml_data(CMD_GET_EVENTS)
    relevant_events = []
    # TODO: work out filters (selectors set by rc's don't work here!!!)
    yaml['items'].each do |event|
      if event['involvedObject'].nil?
        # Can't deal with this event...
        next
      else
        event_name = event['involvedObject']['name'].to_s
        debug "Event data:#{event.to_json}"
        if event_name == pod_name.to_s
          relevant_events << event unless event['lastTimestamp'].nil?
        end
      end
    end
    events_by_time = relevant_events.sort { |a, b| a['lastTimestamp'] <=> b['lastTimestamp'] }
    events_by_time
  end
end