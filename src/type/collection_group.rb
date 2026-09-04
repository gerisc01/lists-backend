require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'

require_relative './collection'
require_relative './account'

# A named, ordered, shared set of collections — what the app calls a BOARD (0085).
#
# It is deliberately not a `Board`: "a named subset of the things one level down" is a
# shape this backend already has in `ListGroup`, and nothing here knows about planners.
# The difference from ListGroup is that this one is STORED rather than embedded — a list
# group is meaningless outside the collection containing it, while a collection group has
# no container at all, only holders. Being stored is also what lets it be shared.
#
# It owns no items. `collections` is a LENS: holding a group grants nothing about the
# collections it names, and a member sees only the intersection with their own
# memberships. The one exception is `one_off_collection` — a scratch pad with no
# independent life, created and destroyed with the group, and granted along with it. It
# is a separate field rather than a member of `collections` on purpose: rotating a
# collection off the lens must never be able to strand the one-offs living in it (0065).
class CollectionGroup

  schema = Schema.new
  schema.key = "collection-group"
  schema.display_name = "Collection Group"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'key', :required => false, :type => String, :display_name => 'Key'},
    {:key => 'name', :required => true, :type => String, :display_name => 'Name'},
    # Ordered: this is the on-screen order of the groups in the planner's pile.
    {:key => 'collections', :required => false, :type => Array, :subtype => Collection, :type_ref => true, :display_name => 'Collections'},
    {:key => 'members', :required => false, :type => Array, :subtype => Account, :type_ref => true, :display_name => 'Members'},
    {:key => 'one_off_collection', :required => false, :type => Collection, :type_ref => true, :display_name => 'One-off Collection'},
  ]
  apply_schema schema

end
