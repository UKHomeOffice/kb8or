require_relative 'kb8_utils'
require 'base64'

class Kb8FileData

  FILE_DATA_KEY = 'Fn::FileData'
  ENC_BASE64 = 'base64'

  attr_accessor :base64_encode,
                :files,
                :name,
                :vars_data

  def initialize(file_data_def, replace_obj_context)
    @vars_data = replace_obj_context.vars
    err_str=" for #{FILE_DATA_KEY} in file #{replace_obj_context.context_path}"

    unless file_data_def.is_a?(Hash)
      raise TypeError, "Invalid data, expecting Hash #{err_str}"
    end
    @name = file_data_def['name']
    unless @name
      raise "Invalid data, missing data for:'name' #{err_str}"
    end
    err_str = " when name='#{@name}' #{err_str}"
    file_paths = file_data_def['files']
    unless file_paths && file_paths.is_a?(Array)
      raise "Invalid data, expecting array for:'files' #{err_str}"
    end

    @files = []
    file_paths.each do | relative_path |
      file = File.join(replace_obj_context.context_path, relative_path)
      unless File.exists?(file)
        raise "Missing file: #{file} specified #{err_str}"
      end
      @files << Kb8Utils.load(file)
    end

    encode_to = file_data_def['encode']
    if encode_to
      @base64_encode = encode_to == ENC_BASE64
    end
  end

  def data
    # Return any data from files...
    data = ''
    @files.each do |file_data|
      data << file_data
    end
    if @base64_encode
      data = Base64.encode64(data)
    end
    data
  end

end