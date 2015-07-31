require 'methadone'

class ReplaceObjVars
  # Class to replace any string references in an object with values from a hash

  REGEXP_VAR = '\${\W*(.*?)\W*}'

  attr_reader :vars
  attr_accessor :updates

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(vars_hash)
    # TODO: walk top level values and parse out "deep merge actions"
    @vars = vars_hash
  end

  def replace(obj)
    ReplaceObjVars.replace(obj, self)
  end

  # Recursive object to replace items as we go:
  def self.replace(obj, context)
    case obj.class.to_s
      when 'String'
        # Detect parse requirements
        case obj.strip
          when /^#{REGEXP_VAR}$/
            # If the entire element is to be replaced:
            key = $1.to_s
            return context.vars[key] if context.vars.has_key?(key)
          when /#{REGEXP_VAR}/
            # Multiple strings found so replace all matching
            /#{REGEXP_VAR}/.match(obj) do | match |
              match.captures.each do |capture|
                key = capture.to_s

                if context.vars.has_key?(key)
                  debug "obj update (multimatch) - #{context.vars[key]}"
                  obj = obj.gsub(/(#{REGEXP_VAR})/, context.vars[key])
                end
              end
            end
          else
            # No more parsing:
            return obj
        end
      when 'Hash'
        # Replace all elements by key...
        obj.each_key do | key |
          obj[key] = ReplaceObjVars.replace(obj[key], context)
        end
      when 'Array'
        obj.each_index do | index |
          obj[index] = ReplaceObjVars.replace(obj[index], context)
        end
      else
        return obj
    end
    obj
  end
end
