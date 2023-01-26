require 'securerandom'
require 'json'
require_relative '../schema/schema'
require_relative '../exceptions'
require_relative '../base/base_type'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'

class Tag < BaseType

  @@schema = Schema.new
  @@schema.key = "tag"
  @@schema.display_name = "Tag"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "key" => {:required => false, :type => String, :display_name => 'Key'},
    "name" => {:required => false, :type => String, :display_name => 'Name'}
  }
  @@schema.apply_schema(self)

  def self.schema
    return @@schema
  end

  module Database

    @@file_name = 'data/tags.json'
  
    file_based_db_and_cache(self, Tag)
  
    define_db_get(self)
    define_db_list(self)
    define_db_save(self)
    define_db_delete(self)
    
  end

end