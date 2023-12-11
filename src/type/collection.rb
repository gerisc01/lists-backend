require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'

require_relative './list'
require_relative './template'
require_relative './list_group'

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
    {:key => 'groups', :required => false, :type => Array, :subtype => ListGroup, :display_name => 'List Groups' }
  ]
  apply_schema schema

end