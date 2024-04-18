require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'
require_relative '../actions/item_actions'

class ActionStep

  schema = Schema.new
  schema.key = "action-step"
  schema.display_name = "Action Step"
  schema.fields = [
    {:key => 'type', :required => true, :type => String, :subtype => String},
    {:key => 'fixed_params', :required => true, :type => Hash, :subtype => String},
    {:key => 'input_params', :required => false, :type => Array, :subtype => String}
  ]
  apply_schema schema

  def process(json)
    action = self.type
    fixed_params = self.fixed_params
    unless fixed_params.nil?
      json = fixed_params.merge(json)
    end

    a = action_methods[action]
    if a.nil?
      raise ListError::NotFound, "Action '#{action}' not found."
    else
      params = a['params'].map { |p| json[p] }
      Kernel.send(a['method'], *params)
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

end