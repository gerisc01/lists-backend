require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'

class ActionStep

  schema = Schema.new
  schema.key = "action-step"
  schema.display_name = "Action Step"
  schema.fields = [
    {:key => 'type', :required => true, :type => String},
    {:key => 'fixed_params', :required => true, :type => Hash, :subtype => String},
    {:key => 'dynamic_params', :required => false, :type => Hash, :subtype => String},
    # Nothing reads this.
    {:key => 'input_params', :required => false, :type => Array, :subtype => String}
  ]
  apply_schema schema

  def process(json)
    # Required here, not at the top: loading it with the types is a require cycle.
    require_relative '../actions/item_actions'
    action = self.type
    fixed_params = self.fixed_params
    if !fixed_params.nil?
      json = fixed_params.merge(json)
    end

    a = action_methods[action]
    if a.nil?
      raise ListError::NotFound, "Action '#{action}' not found."
    else
      params = a['params'].map { |p| json[p] }
      return Kernel.send(a['method'], *params)
    end
  end

end

class Action

  schema = Schema.new
  schema.key = "action"
  schema.display_name = "Action"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'name', :required => true, :type => String, :display_name => 'Name'},
    {:key => 'steps', :required => true, :type => Array, :subtype => ActionStep, :display_name => 'Action Steps'},
    {:key => 'inputs', :required => false, :type => Hash, :subtype => String, :display_name => 'Action Inputs'}
  ]
  apply_schema schema

  def process(json)
    results = {}
    self.steps.each do |step|
      input = json.dup
      if !step.dynamic_params.nil?
        step.dynamic_params.each do |key, value|
          # "step.field" reads `field` from an earlier step's result.
          result_step,result_field = value.split('.')
          result_val = results[result_step]
          if !result_val.nil? && !result_field.nil?
            raise ListError::BadRequest, "Result field '#{result_field}' not found on step '#{result_step}'." if !result_val.respond_to?(result_field)
            input[key] = result_val.send(result_field)
          end
        end
      end
      type = step.type
      results[type] = step.process(input)
    end
  end

end
