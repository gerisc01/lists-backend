require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'

require_relative './list'
require_relative './template'
require_relative './list_group'
require_relative './sharing_scope'
require_relative './account'

class Collection

  schema = Schema.new
  schema.key = "collection"
  schema.display_name = "Collection"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'key', :required => false, :type => String, :display_name => 'Key'},
    {:key => 'name', :required => true, :type => String, :display_name => 'Name'},
    {:key => 'lists', :required => false, :type => Array, :subtype => List, :type_ref => true, :display_name => 'Lists'},
    {:key => 'templates', :required => false, :type => Array, :subtype => Template, :type_ref => true, :display_name => 'Templates'},
    {:key => 'actions', :required => false, :type => Array, :subtype => Action, :type_ref => true, :display_name => 'Actions'},
    {:key => 'tags', :required => false, :type => Array, :subtype => Tag, :type_ref => true, :display_name => 'Tags'},
    {:key => 'groups', :required => false, :type => Array, :subtype => ListGroup, :display_name => 'List Groups' },
    {:key => 'attributes', :required => false, :type => Hash, :display_name => 'Attributes'},
    # Who can access this collection (design §6.1). Structural only; absent reads as 'private'.
    {:key => 'sharing_scope', :required => false, :type => SharingScope, :display_name => 'Sharing Scope'},
    # WHO holds this collection — the single record of access (0086, 0087). It replaced
    # `account.collections`, so the dependency runs Collection → Account and never back:
    # identity does not know about content, which is also what lets this be a real
    # type_ref instead of a hand-validated string array.
    {:key => 'members', :required => false, :type => Array, :subtype => Account, :type_ref => true, :display_name => 'Members'}
  ]
  apply_schema schema

end