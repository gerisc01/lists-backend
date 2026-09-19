require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../exceptions'
require_relative '../storage'

class Account

  schema = Schema.new
  schema.key = "account"
  schema.display_name = "Account"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'name', :required => false, :type => String, :display_name => 'Name'},
    # Client preferences; the server never reads them.
    {:key => 'attributes', :required => false, :type => Hash, :display_name => 'Attributes'},
  ]
  apply_schema schema

end
