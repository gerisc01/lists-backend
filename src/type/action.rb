require 'securerandom'
require 'json'
require_relative '../schema/schema'
require_relative '../exceptions'
require_relative '../base/base_type'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'

class Action < BaseType

  @@schema = Schema.new
  @@schema.key = "action"
  @@schema.display_name = "Action"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "name" => {:required => true, :type => String, :display_name => 'Name'},
    "type" => {:required => true, :type => String, :display_name => 'Type'},
    "parameters" => {:required => false, :type => Map, :subtype => String, :display_name => 'Parameters'}
  }
  @@schema.apply_schema(self)

  def self.schema
    return @@schema
  end

  module Database

    @@file_name = 'data/actions.json'
  
    file_based_db_and_cache(self, Tag)
  
    define_db_get(self)
    define_db_list(self)
    define_db_save(self)
    define_db_delete(self)
    
  end

end