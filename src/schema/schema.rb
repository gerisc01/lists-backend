require_relative './field'
require_relative './custom_types'

class Schema

  attr_accessor :key, :display_name, :fields

  def apply_schema(clazz)
    if !@fields.nil? && !@fields.empty?
      if !@fields[0].is_a?(Field)
        converted_fields = []
        @fields.each { |key, field_def| converted_fields.push(convert_field_def_to_field(key, field_def)) }
        @fields = converted_fields
      end

      @fields.each do |field|
        clazz.define_method(field.key.to_sym) { return self.json[field.key] }
        clazz.define_method("#{field.key}=".to_sym) { |value| self.json[field.key] = value }
      end
    end
  end

  def convert_field_def_to_field(key, field_def)
    field = Field.new
    field.key = key
    field.display_name = field_def['display_name'] || field_def[:display_name]
    field.type = field_def['type'] || field_def[:type]
    field.required = field_def['required'] || field_def[:required]
    return field
  end

  def validate(instance)
    @fields.each do |field|
      begin
        field.validate(instance.public_send(field.key))
      rescue ValidationError => e
        raise ValidationError, "Invalid #{@display_name}: #{e.message}"
      end
    end
  end

end