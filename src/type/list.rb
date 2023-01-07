require 'securerandom'
require 'json'
# require_relative '../db/collection_db'
require_relative '../schema/schema'
require_relative './item'
# require_relative './template'
require_relative '../exceptions'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'

class List

  @@schema = Schema.new
  @@schema.key = "list"
  @@schema.display_name = "List"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "name" => {:required => true, :type => String, :display_name => 'Name'},
    "items" => {:required => false, :type => Array, :subtype => Item, :type_ref => true, :display_name => 'Items'},
    "template" => {:required => false, :type => String, :display_name => 'Template'}
  }
  @@schema.apply_schema(self)

  setup_type_model(self)

  define_get(self)
  define_list(self)
  define_save!(self)
  define_delete!(self)

  module Database

    @@file_name = 'data/lists.json'
  
    file_based_db_and_cache(self, List)
  
    define_db_get(self)
    define_db_list(self)
    define_db_save(self)
    define_db_delete(self)
    
  end

end