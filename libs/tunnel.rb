require 'methadone'
require_relative 'kb8_run'
require 'uri'

class Tunnel

  attr_accessor :tunnel

  SSH_SOCKET = '/tmp/kb8or-ctrl-socket'

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(tunnel,
                 tunnel_options,
                 context)
    @tunnel = tunnel
    @tunnel_options = tunnel_options
    @context = context
  end

  def create()
    uri = URI(@context.settings.kb8_server)
    if @tunnel
      ssh_cmd = "ssh #{@tunnel_options} -M -S #{SSH_SOCKET} -fnNT #{@tunnel} " +
          " -L #{uri.port}:#{uri.host}:#{uri.port}"

      if @leave_tunnel
        puts "Running:\n#{ssh_cmd}"
      else
        debug "Running:\n#{ssh_cmd}"
      end
      Process.spawn(ssh_cmd)
      @context.settings.kb8_server = "#{uri.scheme}://localhost:#{uri.port}"
      # TODO: poll for readyness...
      puts "Waiting for SSH tunnel..."
      sleep 5
    end
  end

  def close()
    # Ensure that the config is updated...
    ssh_close_cmd = "ssh -S #{SSH_SOCKET} -O exit #{@tunnel}"
    if @leave_tunnel
      puts "Tunnel left open (-l), close with command:\n#{ssh_close_cmd}"
    else
      debug "Closing tunnel with command:#{ssh_close_cmd}"
      `#{ssh_close_cmd}`
    end
  end
end

