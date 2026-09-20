require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'

require_relative './collection'
require_relative './account'

# A board in the app: a named, ordered set of collections. Membership grants access only to
# `one_off_collection`, not to `collections` — members see those only if they belong to them.
class CollectionGroup

  schema = Schema.new
  schema.key = "collection-group"
  schema.display_name = "Collection Group"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'key', :required => false, :type => String, :display_name => 'Key'},
    {:key => 'name', :required => true, :type => String, :display_name => 'Name'},
    # The order the planner shows them in.
    {:key => 'collections', :required => false, :type => Array, :subtype => Collection, :type_ref => true, :display_name => 'Collections'},
    {:key => 'members', :required => false, :type => Array, :subtype => Account, :type_ref => true, :display_name => 'Members'},
    {:key => 'one_off_collection', :required => false, :type => Collection, :type_ref => true, :display_name => 'One-off Collection'},
  ]
  apply_schema schema

end
