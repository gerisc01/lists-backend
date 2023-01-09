require_relative '../schema/schema'
require_relative '../generator/type_generator'

class Template < Schema

  def to_object
    convert_fields_to_field_classes()

    result = {
      'key' => self.key,
      'display_name' => self.display_name,
      'fields' => {}
    }
    self.fields.each do |field|
      result['fields'][field.key] = field.to_obj
    end
    return result
  end

  def self.from_object(obj)
    result = Template.new
    result.key = obj['key']
    result.display_name = obj['display_name']
    obj['fields'].each do |key, field_obj|
      result.fields << Field.from_obj(key, field_obj)
    end
    return result
  end

  def self.validate(template)
    raise ListError::Validation, "Invalid template: 'key' is missing or an invalid type" if template.key.nil? || !template.fields.is_a?(String)
    raise ListError::Validation, "Invalid template: 'display_name' is missing or an invalid type" if template.display_name.nil? || !template.fields.is_a?(String)
    raise ListError::Validation, "Invalid template: 'fields' is missing or an invalid_type" if template.fields.nil? || !template.fields.is_a?(Hash)
  end

end