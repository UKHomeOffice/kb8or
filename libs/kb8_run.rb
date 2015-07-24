require 'methadone'

class Kb8Run

  include Methadone::Main
  include Methadone::CLILogging

  CMD_ROLLING_UPDATE = 'kubectl --api-version="v1beta3" rolling-update %s-v%s -f -'
  CMD_CREATE = 'kubectl create -f -'
  CMD_GET_POD = 'kubectl --api-version="v1beta3" get pods -l %s=%s -o yaml'
  CMD_GET_EVENTS = 'kubectl --api-version="v1beta3" get events -o yaml'
  CMD_DELETE_PODS = 'kubectl delete pods -l %s=%s'

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
    IO.popen(cmd, mode) do |subprocess|
      if input
        debug "#{input}"
        subprocess.write(input)
        subprocess.close_write
      end
      subprocess.read.split("\n").each do |line|
        puts line if term_output
        output << "#{line}\n"  if capture
      end
    end
    output
  end

  def self.create(yaml_data)
    Kb8Run.run(CMD_CREATE, true, true, yaml_data.to_s)
  end

  def self.delete_pods(selector_key, selector_value)
    debug "Deleting pods matching selector:#{selector_key}=#{selector_value}"
    cmd = CMD_DELETE_PODS % [selector_key, selector_value]
    Kb8Run.run(cmd, false, true)
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