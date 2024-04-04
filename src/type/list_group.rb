require 'ruby-schema'

require_relative './list'
require_relative './action'

class ListGroup

  schema = Schema.new
  schema.key = "list-group"
  schema.display_name = "List Group"
  schema.fields = [
    {:key => 'key', :required => false, :type => String, :display_name => 'Key'},
    {:key => 'name', :required => false, :type => String, :display_name => 'Name'},
    {:key => 'lists', :required => false, :type => Array, :subtype => List, :type_ref => true, :display_name => 'Lists'},
    {:key => 'actions', :required => false, :type => Array, :subtype => Action, :type_ref => true, :display_name => 'Actions'}
  ]
  apply_schema schema

end