require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'
class Action

  schema = Schema.new
  schema.key = "action"
  schema.display_name = "Action"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'name', :required => true, :type => String, :display_name => 'Name'},
    {:key => 'type', :required => true, :type => String, :display_name => 'Type'},
    {:key => 'parameters', :required => false, :type => Hash, :subtype => String, :display_name => 'Parameters'}
  ]
  apply_schema schema

end