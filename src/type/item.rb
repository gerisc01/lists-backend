require 'securerandom'
require 'json'
require_relative '../schema/schema'
require_relative '../type/tag'
require_relative '../type/template'
require_relative '../exceptions'
require_relative '../base/base_type'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'

class Item < BaseType

  @@schema = Schema.new
  @@schema.key = "item"
  @@schema.display_name = "Item"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "name" => {:required => true, :type => String, :display_name => 'Name'},
    "templates" => {:required => false, :type => Array, :subtype => Template, :type_ref => true, :set => true, :display_name => 'Template'},
    "tags" => {:required => false, :type => Array, :subtype => Tag, :type_ref => true, :display_name => 'Tags'}
  }
  @@schema.apply_schema(self)

  def self.schema
    return @@schema
  end

  def validate
    @@schema.validate(self)
    unless self.templates.nil?
      self.templates.each do |template_id|
        Template.get(template_id).validate(self)
      end
    end
  end

  module Database

    @@file_name = 'data/items.json'
  
    file_based_db_and_cache(self, Item)
  
    define_db_get(self)
    define_db_list(self)
    define_db_save(self)
    define_db_delete(self)
    
  end

end