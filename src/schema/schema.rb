require_relative './field'
require_relative './custom_types'

class Schema

  attr_accessor :key, :display_name, :fields

  def validate(instance)
    @fields.each do |field|
      begin
        field.validate(instance.public_send(field.key))
      rescue ValidationError => e
        raise ValidationError, "Invalid #{@display_name}: #{e.message}"
      end
    end
  end

  def apply_schema(clazz)
    schema_self = self

    return if @fields.nil?
    convert_fields_to_field_classes()
    add_base_fields_to_class(clazz)
    add_array_fields_to_class(clazz, schema_self)
    add_hash_fields_to_class(clazz, schema_self)

  end

  ###################################################################
  #                       HELPER METHODS                            #
  ###################################################################

  private

  def convert_fields_to_field_classes
    converted_fields = []
    @fields.each do |key, field_def|
      converted_fields.push(!key.is_a?(Field) ? Field.from_obj(key, field_def) : key)
    end
    @fields = converted_fields
  end

  def add_base_fields_to_class(clazz)
    @fields.each do |field|
      clazz.define_method(field.key.to_sym) do
        self.json = {} if json.nil?
        return self.json[field.key]
      end
      
      clazz.define_method("#{field.key}=".to_sym) do |value|
        self.json = {} if json.nil?
        self.json[field.key] = value
      end
    end
  end

  def add_array_fields_to_class(clazz, schema_self)
    @fields.select { |f| [Array, Set].include?(f.type) }.each do |field|
      singular_key = field.key[-1] == "s" ? field.key[0...-1] : field.key
      type = field.subtype || field.type

      clazz.define_method("add_#{singular_key}".to_sym) do |value|
        field.validate([value])
        value = schema_self.process_type_ref(value, type) if field.type_ref
        self.json = {} if self.json.nil?
        self.json[field.key] = [] if self.json[field.key].nil?
        self.json[field.key] << value
      end

      clazz.define_method("remove_#{singular_key}".to_sym) do |value|
        return if self.json[field.key].nil?
        value = value.id if field.type_ref && value != nil && value.respond_to?(:id)
        self.json[field.key].delete(value)
      end
      
    end
  end

  def add_hash_fields_to_class(clazz, schema_self)
    @fields.select { |f| [Hash].include?(f.type) }.each do |field|
      singular_key = field.key[-1] == "s" ? field.key[0...-1] : field.key
      type = field.subtype || field.type

      clazz.define_method("add_#{singular_key}".to_sym) do |k, v = nil|
        if v == nil
          v = k
          k = v.id
        end
        self.json = {} if self.json.nil?
        self.json[field.key] = {} if self.json[field.key].nil?
        raise BadRequestError, "Bad Request: Cannot add #{singular_key} to hash because key already exists" if self.json[field.key].has_key?(k)
        raise ValidationError, "Validation Error: Cannot add #{singular_key} because it doesn't have an id" if k.nil?
        field.validate({k => v})
        v = schema_self.process_type_ref(v, type) if field.type_ref
        self.json[field.key][k] = v
      end

      clazz.define_method("upsert_#{singular_key}".to_sym) do |k, v = nil|
        if v == nil
          v = k
          k = v.id
        end
        self.json = {} if self.json.nil?
        self.json[field.key] = {} if self.json[field.key].nil?
        field.validate({k => v})
        raise ValidationError, "Validation Error: Cannot add #{singular_key} because it doesn't have an id" if k.nil?
        v = schema_self.process_type_ref(v, type) if field.type_ref
        self.json[field.key][k] = v
      end

      clazz.define_method("remove_#{singular_key}".to_sym) do |v|
        return if self.json[field.key].nil?
        v = v.id if v.respond_to?(:id)
        self.json[field.key].delete(v)
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

end