require 'securerandom'
require 'json'
require_relative '../schema/schema'
require_relative './list'
require_relative './template'
require_relative './list_group'
require_relative '../exceptions'
require_relative '../base/base_type'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'

class Collection < BaseType

  @@schema = Schema.new
  @@schema.key = "collection"
  @@schema.display_name = "Collection"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "key" => {:required => false, :type => String, :display_name => 'Key'},
    "name" => {:required => true, :type => String, :display_name => 'Name'},
    "lists" => {:required => false, :type => Array, :subtype => List, :type_ref => true, :display_name => 'Lists'},
    "templates" => {:required => false, :type => Hash, :subtype => Template, :display_name => 'Templates'},
    "groups" => {:required => false, :type => Array, :subtype => ListGroup, :display_name => 'List Groups' }
  }
  @@schema.apply_schema(self)

  def self.schema
    return @@schema
  end

  module Database

    @@file_name = 'data/collections.json'
  
    file_based_db_and_cache(self, Collection)
  
    define_db_get(self)
    define_db_list(self)
    define_db_save(self)
    define_db_delete(self)
    
  end

end