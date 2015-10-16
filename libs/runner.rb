require 'open3'

class Runner

  attr_accessor :status,
                :stdout,
                :stderr,
                :output,
                :outputted,
                :screen

  def initialize(cmd, output, input)

    @output = output

    # see: http://stackoverflow.com/a/1162850/83386
    Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
      stdin.puts input.to_s
      stdin.close
      $stdout.sync = true

      # read each stream from a new thread
      { :out => stdout, :err => stderr }.each do |key, stream|
        Thread.new() do
          until (line = stream.gets).nil? do
            $stdout.sync = true
            if key == :out
              @stdout = "#{@stdout}#{line}"
              if @output
                if line.length > 0 && (!@outputted)
                  puts "\tOutput from '#{cmd}':"
                end
                puts "\t#{line}"
                @outputted = true
              end
            else
              @stderr = "#{@stderr}#{line.dup}"
            end
          end
        end
      end
      thread.join # don't exit until the external process is done
      @status = thread.value
    end
  end
end
