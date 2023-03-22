require 'securerandom'
require 'json'
require_relative '../schema/schema'
require_relative '../type/tag'
require_relative '../type/template'
require_relative '../exceptions'
require_relative '../base/base_type'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'
require_relative './item_generic'

class ItemGroup < BaseType

  @@schema = Schema.new
  @@schema.key = "item_group"
  @@schema.display_name = "Item Group"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "name" => {:required => true, :type => String, :display_name => 'Name'},
    "group" => {:required => true, :type => Array, :subtype => Item, :type_ref => true, :display_name => 'Grouped Items'}
  }
  @@schema.apply_schema(self)

  def self.schema
    return @@schema
  end

  def add_template(template)
    self.group.each do |item_id|
      it = Item.get(item_id)
      it.add_template(template)
      it.save!
    end
  end

  def remove_template(template)
    self.group.each do |item_id|
      it = Item.get(item_id)
      it.remove_template(template)
      it.save!
    end
  end

  module Database

    @@file_name = 'data/item-groups.json'
  
    file_based_db_and_cache(self, ItemGroup)
  
    define_db_get(self)
    define_db_list(self)
    define_db_save(self)
    define_db_delete(self)
    
  end

end