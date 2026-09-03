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
    # Prefs home (mirrors List/Collection/Template). Holds deferred UI prefs — the
    # §4.3 default-headers config and the §6.2 per-account view dial. Unread for now.
    {:key => 'attributes', :required => false, :type => Hash, :display_name => 'Attributes'},
  ]
  apply_schema schema

end
