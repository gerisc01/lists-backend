require_relative './field'
require_relative './custom_types'

class Schema

  attr_accessor :key, :display_name, :fields

  def apply_schema(clazz)
    schema_self = self

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

      # Array methods
      @fields.select { |f| [Array, Set].include?(f.type) }.each do |field|
        singular_key = field.key[-1] == "s" ? field.key[0...-1] : field.key
        type = field.subtype || field.type

        clazz.define_method("add_#{singular_key}".to_sym) do |value|
          field.validate_collection_element(value, field)
          value = schema_self.process_type_ref(value, type) if field.type_ref
          self.json[field.key] = [] if self.json[field.key].nil?
          self.json[field.key] << value
        end

        clazz.define_method("remove_#{singular_key}".to_sym) do |value|
          return if self.json[field.key].nil?
          value = value.id if field.type_ref && value != nil && value.respond_to?(:id)
          self.json[field.key].delete(value)
        end
        
      end

      # Hash methods
      @fields.select { |f| [Hash].include?(f.type) }.each do |field|
        singular_key = field.key[-1] == "s" ? field.key[0...-1] : field.key
        type = field.subtype || field.type

        clazz.define_method("add_#{singular_key}".to_sym) do |value|
          self.json[field.key] = {} if self.json[field.key].nil?
          raise BadRequestError, "Bad Request: Cannot add #{singular_key} to hash because id already exists" if self.json[field.key].has_key?(id)
          raise ValidationError, "Validation Error: Cannot add #{singular_key} because it doesn't have an id" if !value.respond_to?(:id)
          field.validate_collection_element(value, field)
          value = schema_self.process_type_ref(value, type) if field.type_ref
          self.json[field.key][value.id] = value
        end

        clazz.define_method("upsert_#{singular_key}".to_sym) do |value|
          self.json[field.key] = {} if self.json[field.key].nil?
          field.validate_collection_element(value, field)
          raise ValidationError, "Validation Error: Cannot add #{singular_key} because it doesn't have an id" if !value.respond_to?(:id)
          value = schema_self.process_type_ref(value, type) if field.type_ref
          self.json[field.key][value.id] = value
        end

        clazz.define_method("remove_#{singular_key}".to_sym) do |value|
          return if self.json[field.key].nil?
          value = value.id if value.respond_to?(:id)
          self.json[field.key].delete(value)
        end
        
      end
    end
  end

  def process_type_ref(value, type_ref)
    raise ValidationError, "Invalid Type Ref: Expecting '#{type_ref.to_s}' but received '#{value.class.to_s}'" if !value.is_a?(type_ref) && !value.is_a?(String)
    if value.is_a?(type_ref)
      raise ValidationError, "Invalid Type Ref: Received a type ref instance of type '#{type_ref.to_s}' without an :id method" if !value.respond_to?(:id)
      value.save! if !type_ref.public_send(:exist?, value.id)
      id = value.id
    else
      id = value
      raise ValidationError, "Invalid Type Ref: Can't add type ref instance with id '#{id}' because an object matching the id doesn't exist" if !type_ref.public_send(:exist?, id)
    end
    return id
  end

  def convert_field_def_to_field(key, field_def)
    field = Field.new
    field.key = key
    field.display_name = field_def['display_name'] || field_def[:display_name]
    field.type = field_def['type'] || field_def[:type]
    field.subtype = field_def['subtype'] || field_def[:subtype]
    field.required = field_def['required'] || field_def[:required]
    field.type_ref = field_def['type_ref'] || field_def[:type_ref]
    validate_field_def(field)
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

  def validate_field_def(field)
    ## TODO: If this concept works, add a check for a field def to throw an error if type/subtype aren't
    # set and type_ref == true. Also, type class should have following fields: [:id, :exist?, :save!]
  end

end