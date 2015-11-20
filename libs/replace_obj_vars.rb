require_relative 'kb8_utils'
require_relative 'kb8_file_data'

class ReplaceObjVars
  # Class to replace any string references in an object with values from a hash

  REGEXP_SPECIFIC_VAR = '\${\W*(%s)\W*}'
  REGEXP_VAR = REGEXP_SPECIFIC_VAR % '.*?'
  FILE_INCLUDE = 'file://'
  INCLUDE_KEYS = %w(Fn::FileIncludePaths FileIncludePaths)
  MERGE_KEY = 'Fn::OptionalHashItem'

  attr_reader :context_path,
              :vars
  attr_accessor :updates

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(vars_hash, context_path)
    @context_path = context_path
    @vars = vars_hash
  end

  def replace(obj)
    ReplaceObjVars.replace(obj, self)
  end

  def self.load_file(file_name, root)
    path = get_path(file_name, root)
    file_data = Kb8Utils.load_yaml(File.open(path))
    file_data
  end

  def self.get_path(file_name, root)
    if file_name.start_with?('/')
      path = file_name
    else
      path = File.join(root, file_name)
    end
    path
  end

  # Recursive object to replace items as we go:
  def self.replace(obj, replace_obj_context)
    case obj.class.to_s
      when 'String'
        # Detect parse requirements
        case obj.strip
          when /^#{REGEXP_VAR}$/
            # If the entire element is to be replaced:
            key = $1.to_s
            obj = replace_obj_context.vars[key] if replace_obj_context.vars.has_key?(key)
            return obj
          when /#{REGEXP_VAR}/
            # Multiple strings found so replace all matching
            obj.scan(/#{REGEXP_VAR}/).flatten.each do | match_string |
              key = match_string.to_s
              if replace_obj_context.vars.has_key?(key)
                # This needs to handle multiple vars in the same string
                capture_regexp = REGEXP_SPECIFIC_VAR % key
                obj = obj.gsub(/(#{capture_regexp})/, replace_obj_context.vars[key].to_s)
              end
            end
          else
            # No more parsing:
            return obj
        end
      when 'Hash'
        # Replace all elements by key...
        files = []
        merge_items = []
        obj.each_key do | key |
          # Detect Special markup here:
          case key
            when *INCLUDE_KEYS
              files << obj[key]
              files  = files.flatten(1)
            when MERGE_KEY
              merge_items << obj[key]
              merge_items = merge_items.flatten(1)
            when Kb8FileData::FILE_DATA_KEY
              unless obj[key].is_a?(Array)
                raise "Invalid data for #{Kb8FileData::FILE_DATA_KEY}, expecting an array."
              end
              obj[key].each do | file_set |
                file_data = Kb8FileData.new(file_set, replace_obj_context)
                merge_items << { file_data.name.dup => file_data.data }
              end
            else
          end
        end
        merge_items.each do | merge_item |
          # We'll add back any values here:
          if merge_item
            merge_value = ReplaceObjVars.replace(merge_item, replace_obj_context)
            if merge_value.is_a?(Hash)
              obj = obj.merge(merge_value)
              # We've done the replacement, delete the item...
              obj.delete(MERGE_KEY)
            end
            if merge_value.nil?
              # Substitution when there is no item (NOT when FALSE)
              obj.delete(MERGE_KEY)
            end
          end
        end
        new_data = {}
        files.each do | file |
          file_data = load_file(file, replace_obj_context.context_path)
          new_data = file_data.merge(new_data)
        end
        obj = obj.merge(new_data)
        obj.each_key do | key |
          obj[key] = ReplaceObjVars.replace(obj[key], replace_obj_context)
        end
      when 'Array'
        obj.each_index do | index |
          obj[index] = ReplaceObjVars.replace(obj[index], replace_obj_context)
        end
      else
        return obj
    end
    obj
  end
end
