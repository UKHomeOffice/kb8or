require 'methadone'

class Kb8Run

  include Methadone::Main
  include Methadone::CLILogging

  CMD_ROLLING_UPDATE = 'kubectl rolling-update %s-v%s -f -'
  CMD_CREATE = 'kubectl create -f -'
  GET_POD = 'kubectl get pods -l %s=%s -o yaml'

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

  def self.get_pod_status(selector_key, selector_value)
    debug "Get pods with selector '#{selector_key}' with value:'#{selector_value}'"
    cmd = GET_POD % [selector_key, selector_value]
    kb8_out = Kb8Run.run(cmd, true, false)
    debug "Loading YAML data from kubectl:\n#{kb8_out}"
    yaml = YAML.load(kb8_out)
    debug "YAML loaded..."
    yaml
  end
end