require 'securerandom'
require 'json'
# require_relative '../db/collection_db'
require_relative '../schema/schema'
require_relative './list'
# require_relative './template'
require_relative '../exceptions'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'

class Collection

  @@schema = Schema.new
  @@schema.key = "collection"
  @@schema.display_name = "Collection"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "key" => {:required => false, :type => String, :display_name => 'Key'},
    "name" => {:required => true, :type => String, :display_name => 'Name'}
  }
  @@schema.apply_schema(self)

  setup_type_model(self)

end