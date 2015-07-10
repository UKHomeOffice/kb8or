class Kb8Run

  def self.run(cmd, capture=false, term_output=true, input=nil)

    # pipe if specifying input
    cmd = "| #{cmd}" if input
    if input
      mode = 'w+'
    else
      mode = 'r'
    end

    output = ''
    # Run process and capture output if required...
    IO.popen(cmd, mode) do |subprocess|
      if input
        subprocess.write(input)
        subprocess.close_write
      end
      subprocess.read.split("\n").each do |line|
        puts line if term_output
        output << line if capture
      end
    end
    output
  end

end