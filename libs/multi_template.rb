require 'methadone'
require_relative 'kb8_resource'

class MultiTemplate

  include Methadone::Main
  include Methadone::CLILogging

  attr_accessor :dir,
                :kb8_data,
                :template_file,
                :items,
                :template_data,
                :template_name,
                :valid_data

  def self.get_new_item(vars_data, new_resource_name, template_data, context, file)
    kb8_data = Marshal.load(Marshal.dump(template_data))

    # Copy the var data...
    new_vars = vars_data.dup

    # Create a context with the new data:
    item_context = context.new_with_vars(new_vars)
    # Now resolve the vars data with itself...
    new_vars = item_context.resolve_vars(new_vars)

    # OK so there's a recursive thing here, lets handle two levels deep...
    item_context = item_context.new_with_vars(new_vars)
    # Now resolve the vars data with itself...
    new_vars = item_context.resolve_vars(new_vars)

    # Finally, use the latest data:
    item_context = item_context.new_with_vars(new_vars)
    resource_data = item_context.resolve_vars(kb8_data)

    # Overwrite the name of the resource with the generated name:
    resource_data['metadata']['name'] = new_resource_name

    # Now add the resource...
    resource  = Kb8Resource.get_resource_from_data(resource_data, file, item_context)
    resource
  end

  def initialize(kb8_data, context, file, dir)
    template_data = kb8_data.dup
    @items = []
    unless context.settings.multi_template.has_key?('Name')
      raise "Invalid deployment unit (Missing Name attribute) for MultiTemplate setting for path:#{dir}"
    end

    @template_name = context.settings.multi_template['Name']
    @valid_data = Kb8Resource.new(template_data, file).name == @template_name

    if @valid_data
      # Create things based on

      # Create items based on Vars

      # 1. Create a new context for the Item...
      unless context.settings.multi_template.has_key?('Items')
        raise "Invalid deployment unit (Missing tag 'Items') for MultiTemplate setting for path:#{dir}"
      end
      context.settings.multi_template['Items'].each do | item |
        # Update name to match value specified:
        # metadata:
        #   name: es-master
        unless item.has_key?('Name')
          raise "Invalid deployment unit (Missing tag 'Name') for a MultiTemplate Item for path:#{dir}"
        end
        name = item['Name']
        vars_data = nil
        vars_data = item['Vars'] if item.has_key?('Vars')

        # Load any enum vars...
        if item.has_key?('EnumVar')
          unless item['EnumVar'].has_key?('Name')
            raise "Invalid deployment unit (Missing tag 'Name') for an EnumVar in a MultiTemplate Item for path:#{dir}"
          end
          enum_var_name = item['EnumVar']['Name']
          unless item['EnumVar'].has_key?('Values')
            raise "Invalid deployment unit (Missing tag 'Values') for an EnumVar in a MultiTemplate Item for path:#{dir}"
          end
          item['EnumVar']['Values'].each do | value |
            # Copy the var data
            enum_vars = vars_data.dup
            # Populate the Vars with the correct enum value:
            enum_vars[enum_var_name] = value
            @items << MultiTemplate.get_new_item(enum_vars, "#{name}-#{value}", template_data, context, file)
          end
        else
          @items << MultiTemplate.get_new_item(vars_data, name, template_data, context, file)
        end
      end
    end
  end

  def valid_data?
    @valid_data
  end

end