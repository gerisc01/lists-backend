require_relative '../schema/schema'
require_relative '../base/base_type'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'

class Template < Schema

  ## Accessor definitions

  define_get(self)
  define_get_by_key(self)
  define_exist?(self)
  define_list(self)
  define_save!(self)
  define_delete!(self)

  ## Database definitions

  module Database

    @@file_name = 'data/templates.json'
  
    file_based_db_and_cache(self, Template)
  
    define_db_get(self)
    define_db_list(self)
    define_db_save(self)
    define_db_delete(self)
    
  end

  ## Override of schema definition fields normally defined through apply_schema() and setup_type_model()

  attr_accessor :id, :key, :display_name, :fields

  def self.is_schema_class?
    return true
  end

  def initialize(json = nil)
    if !json.nil?
      @key = json['key']
      @display_name = json['display_name']
      @fields = json['fields']
      convert_fields_to_field_classes()
    end
    @id = (!json.nil? && json['id']) || SecureRandom.uuid
  end

  def validate(instance = nil)
    if instance.nil?
      Template.validate(self)
    else
      super(instance)
    end
  end

  def to_object
    convert_fields_to_field_classes()

    result = {
      'id' => @id,
      'key' => @key,
      'display_name' => @display_name,
      'fields' => {}
    }
    @fields.each do |field|
      result['fields'][field.key] = field.to_obj
    end
    return result
  end

  def self.from_object(obj)
    result = Template.new
    result.id = obj['id']
    result.key = obj['key']
    result.display_name = obj['display_name']
    result.fields = []
    obj['fields'].each do |key, field_obj|
      result.fields << Field.from_obj(key, field_obj)
    end
    return result
  end

  def merge!(update_json)
    current_json = self.to_object
    new_obj = Template.from_object(current_json.merge(update_json))
    @id = new_obj.id
    @key = new_obj.key
    @display_name = new_obj.display_name
    @fields = new_obj.fields
  end

  def json
    self.to_object
  end

  def self.validate(template)
    raise ListError::Validation, "Invalid template: 'key' is missing or an invalid type" if template.key.nil? || !template.key.is_a?(String)
    raise ListError::Validation, "Invalid template: 'display_name' is missing or an invalid type" if template.display_name.nil? || !template.display_name.is_a?(String)
    raise ListError::Validation, "Invalid template: 'fields' is missing or an invalid_type" if template.fields.nil? || !(template.fields.is_a?(Hash) || template.fields.is_a?(Array))
  end

end