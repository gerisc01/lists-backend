require 'securerandom'
require 'json'
# require_relative '../db/collection_db'
require_relative '../schema/schema'
# require_relative './template'
require_relative '../exceptions'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'

class Item

  @@schema = Schema.new
  @@schema.key = "item"
  @@schema.display_name = "Item"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "name" => {:required => true, :type => String, :display_name => 'Name'},
    "schema" => {:required => false, :type => Schema, :display_name => 'Schema'} 
  }
  @@schema.apply_schema(self)

  setup_type_model(self)

  define_get(self)
  define_exist?(self)
  define_list(self)
  define_save!(self)
  define_delete!(self)

  module Database

    @@file_name = 'data/items.json'
  
    file_based_db_and_cache(self, Item)
  
    define_db_get(self)
    define_db_list(self)
    define_db_save(self)
    define_db_delete(self)
    
  end

end