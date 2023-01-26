require 'securerandom'
require 'json'
require_relative '../schema/schema'
require_relative './list'
require_relative '../exceptions'
require_relative '../base/base_type'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'

class ListGroup < BaseType

  @@schema = Schema.new
  @@schema.key = "list-group"
  @@schema.display_name = "List Group"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "key" => {:required => false, :type => String, :display_name => 'Key'},
    "name" => {:required => false, :type => String, :display_name => 'Name'},
    "lists" => {:required => false, :type => Array, :subtype => List, :type_ref => true, :display_name => 'Lists'},
  }
  @@schema.apply_schema(self)

  def self.schema
    return @@schema
  end

end