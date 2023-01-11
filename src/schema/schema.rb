require_relative './field'
require_relative './custom_types'

class Schema

  attr_accessor :key, :display_name, :fields

  def initialize
    @fields = []
  end

  def validate(instance)
    @fields.each do |field|
      begin
        field.validate(instance.public_send(field.key))
      rescue ListError::Validation => e
        raise ListError::Validation, "Invalid #{@display_name}: #{e.message}"
      end
    end
  end

  def apply_schema(clazz)
    schema_self = self
    clazz.define_singleton_method(:is_schema_class?) do
      return true
    end

    return if @fields.nil?
    convert_fields_to_field_classes()
    add_base_fields_to_class(clazz, schema_self)
    add_array_fields_to_class(clazz, schema_self)
    add_hash_fields_to_class(clazz, schema_self)
  end

  ###################################################################
  #                       HELPER METHODS                            #
  ###################################################################

  def convert_fields_to_field_classes
    converted_fields = []
    @fields.each do |key, field_def|
      converted_fields.push(!key.is_a?(Field) ? Field.from_obj(key, field_def) : key)
    end
    @fields = converted_fields
  end

  def add_base_fields_to_class(clazz, schema_self)
    @fields.each do |field|
      clazz.define_method(field.key.to_sym) do
        self.instance_variable_set("@#{field.key.to_sym}", nil) if !self.instance_variable_defined?("@#{field.key.to_sym}")
        result = self.instance_variable_get("@#{field.key.to_sym}")
        return result if result != nil

        self.json = {} if json.nil?
        value = self.json[field.key]
        result = schema_self.convert_json_val_to_type(field, value)
        self.instance_variable_set("@#{field.key.to_sym}", result)
        return result
      end
      
      clazz.define_method("#{field.key}=".to_sym) do |value|
        self.json = {} if json.nil?
        json_val = schema_self.convert_type_to_json_val(field, value)
        self.json[field.key] = json_val
        result = schema_self.convert_json_val_to_type(field, value)
        self.instance_variable_set("@#{field.key.to_sym}", result)
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
        self.instance_variable_set("@#{field.key.to_sym}", self.json[field.key])
      end

      clazz.define_method("remove_#{singular_key}".to_sym) do |value|
        return if self.json[field.key].nil?
        value = value.id if field.type_ref && value != nil && value.respond_to?(:id)
        self.json[field.key].delete(value)
        self.instance_variable_set("@#{field.key.to_sym}", self.json[field.key])
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
        raise ListError::BadRequest, "Bad Request: Cannot add #{singular_key} to hash because key already exists" if self.json[field.key].has_key?(k)
        raise ListError::Validation, "Validation Error: Cannot add #{singular_key} because it doesn't have an id" if k.nil?
        field.validate({k => v})
        v = schema_self.process_type_ref(v, type) if field.type_ref
        self.json[field.key][k] = v
        self.instance_variable_set("@#{field.key.to_sym}", self.json[field.key])
      end

      clazz.define_method("upsert_#{singular_key}".to_sym) do |k, v = nil|
        if v == nil
          v = k
          k = v.id
        end
        self.json = {} if self.json.nil?
        self.json[field.key] = {} if self.json[field.key].nil?
        field.validate({k => v})
        raise ListError::Validation, "Validation Error: Cannot add #{singular_key} because it doesn't have an id" if k.nil?
        v = schema_self.process_type_ref(v, type) if field.type_ref
        self.json[field.key][k] = v
        self.instance_variable_set("@#{field.key.to_sym}", self.json[field.key])
      end

      clazz.define_method("remove_#{singular_key}".to_sym) do |v|
        return if self.json[field.key].nil?
        v = v.id if v.respond_to?(:id)
        self.json[field.key].delete(v)
        self.instance_variable_set("@#{field.key.to_sym}", self.json[field.key])
      end
      
    end
  end

  def process_type_refs(values, type_ref)
    if values.is_a?(Array)
      result = values.map { |it| process_type_ref(it, type_ref) }
    elsif values.is_a?(Hash)
      result = {}
      values.each { |key, it| result[key] = process_type_ref(it, type_ref) }
    end
    return result
  end

  def process_type_ref(value, type_ref)
    raise ListError::Validation, "Invalid Type Ref: Expecting '#{type_ref.to_s}' but received '#{value.class.to_s}'" if !value.is_a?(type_ref) && !value.is_a?(String)
    if value.is_a?(type_ref)
      raise ListError::Validation, "Invalid Type Ref: Received a type ref instance of type '#{type_ref.to_s}' without an :id method" if !value.respond_to?(:id)
      value.save! if !type_ref.public_send(:exist?, value.id)
      id = value.id
    else
      id = value
      raise ListError::Validation, "Invalid Type Ref: Can't add type ref instance with id '#{id}' because an object matching the id doesn't exist" if !type_ref.public_send(:exist?, id)
    end
    return id
  end
  
  def convert_json_val_to_type(field, value)
    result = value
    if value.is_a?(Hash) && is_schema_class?(field.type)
      # If it's a top level typeref
      result = field.type.new(value)
      result = process_type_ref(result, field.type) if field.type_ref
    elsif value.is_a?(Hash) && field.type == Hash && is_schema_class?(field.subtype)
      # If it's a hash collection with children typeref
      result = {}
      value.each do |key, subvalue|
        result[key] = subvalue.is_a?(Hash) ? field.subtype.new(subvalue) : subvalue
      end
      result = process_type_refs(result, field.subtype) if field.type_ref
    elsif value.is_a?(Array) && field.type == Array && is_schema_class?(field.subtype)
      # If it's an array collection with children typeref
      result = value.map { |it| it.is_a?(Hash) ? field.subtype.new(it) : it }
      result = process_type_refs(result, field.subtype) if field.type_ref
    end
    return result
  end

  def convert_type_to_json_val(field, type_val)
    result = type_val
    if field.type.respond_to?(:is_schema_class?) && field.type.is_schema_class? && type_val.is_a?(field.type)
      result = type_val.json
    elsif type_val.is_a?(Hash) && field.type == Hash && field.subtype.respond_to?(:is_schema_class?) && field.subtype.is_schema_class?
      result = {}
      value.each do |key, subvalue|
        result[key] = subvalue.json
      end
    elsif type_val.is_a?(Array) && field.type == Array && field.subtype.respond_to?(:is_schema_class?) && field.subtype.is_schema_class?
      result = value.map { |it| it.json }
    end
    return result
  end

  def is_schema_class?(type)
    return type.respond_to?(:is_schema_class?) && type.is_schema_class?
  end

end