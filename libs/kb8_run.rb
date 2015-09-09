require 'methadone'

class Kb8Run

  include Methadone::Main
  include Methadone::CLILogging

  API_VERSION = 'v1'
  CMD_ROLLING_UPDATE = "kubectl --api-version=\"#{API_VERSION}\" rolling-update %s-v%s -f -"
  CMD_CREATE = 'kubectl create -f -'
  CMD_DELETE = 'kubectl delete %s/%s'
  CMD_GET_POD_LOGS = 'kubectl logs %s'
  CMD_GET_POD = "kubectl --api-version=\"#{API_VERSION}\" get pods -l %s=%s -o yaml"
  CMD_GET_EVENTS = "kubectl --api-version=\"#{API_VERSION}\" get events -o yaml"
  CMD_GET_RESOURCE = "kubectl --api-version=\"#{API_VERSION}\" get %s -o yaml"
  CMD_DELETE_PODS = 'kubectl delete pods -l %s=%s'
  CMD_CONFIG_CLUSTER = 'kubectl config set-cluster %s --server=%s'
  CMD_CONFIG_CONTEXT = 'kubectl config set-context kb8or-context --cluster=%s --namespace=%s'
  CMD_CONFIG_DEFAULT = 'kubectl config use-context kb8or-context'

  def self.run(cmd, capture=false, term_output=true, input=nil)

    # pipe if specifying input
    if input
      mode = 'w+'
    else
      mode = 'r'
    end

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
      unless $?.success?
        raise "Error running #{cmd}:\n#{output}"
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
    events_by_time = relevant_events.sort_by { |v| v['FirstTimestamp'] }
    events_by_time
  end
end