require 'ruby-schema'

class TypeRefClass

  attr_accessor :id, :json

  def initialize(json = nil)
    @json = json
    @json['id'] = '1' if @json['id'].nil?
    self.id = @json['id']
  end

  def self.exist?(id)
    return id.to_i < 99
  end

  def save!
  end

  def self.is_schema_class?
    true
  end

end

class GenericClass
  attr_accessor :json
end

class GenericSchemaClass
  schema = Schema.new
  schema.key = "test"
  schema.display_name = "Test Schema"
  schema.fields = {
    # Required
    "field_required" => {:required => true},
    "field_not_required" => {:required => false},
    # Type
    "field_type_string" => {:type => String},
    "field_type_int" => {:type => Integer},
    "field_type_custom" => {:type => SchemaType::Boolean},
    # Subtype Array
    "field_type_array_int" => {:type => Array, :subtype => Integer},
    "field_type_array_custom" => {:type => Array, :subtype => SchemaType::Boolean},
    # Subtype Hash
    "field_type_hash_int" => {:type => Hash, :subtype => Integer},
    "field_type_hash_custom" => {:type => Hash, :subtype => SchemaType::Boolean},
    # Type Ref
    "field_typeref" => {:type => TypeRefClass},
    "field_array_typeref" => {:type => Array, :subtype => TypeRefClass},
    "field_hash_typeref" => {:type => Hash, :subtype => TypeRefClass}
  }
  apply_schema schema
end

class EmptySchemaClass
  schema = Schema.new
  apply_schema schema
end