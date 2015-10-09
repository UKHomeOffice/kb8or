require 'open3'

class SafeRunner

  attr_accessor :status,
                :stdout,
                :stderr,
                :output,
                :outputted,
                :screen

  def initialize(cmd, output, input)

    @output = output
    $stdout.sync = true

    @stdout, @stderr, @status = Open3.capture3(cmd, :stdin_data=>input)
    if @output
      @stdout.each_line do | line|
        if line.length > 0 && (!@outputted)
          puts "\tOutput from '#{cmd}':"
        end
        puts "\t#{line}"
        @outputted = true
      end
    end
  end
end
