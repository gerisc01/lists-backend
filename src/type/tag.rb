require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../exceptions'
require_relative '../storage'

class Tag

  schema = Schema.new
  schema.key = "tag"
  schema.display_name = "Tag"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'key', :required => false, :type => String, :display_name => 'Key'},
    {:key => 'name', :required => false, :type => String, :display_name => 'Name'}
  ]
  apply_schema schema

end