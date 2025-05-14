require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../exceptions'
require_relative '../storage'
require_relative './collection'

class Account

  schema = Schema.new
  schema.key = "account"
  schema.display_name = "Account"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'name', :required => false, :type => String, :display_name => 'Name'},
    {:key => 'collections', :required => false, :type => Array, :subtype => Collection, :type_ref => true, :display_name => 'Collections'},
  ]
  apply_schema schema

end
