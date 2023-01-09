require_relative './custom_types'
require_relative '../exceptions'

class Field

  attr_accessor :key, :display_name, :type, :subtype, :required, :type_ref

  ## key:           unique identifying string with no spaces
  ## display_name:  a display name optionally used by downstream systems
  ## type:          name of a ruby class
  ## subtype:       name of a ruby class that is used for collection validation
  ## required:      boolean
  ## type_ref:      boolean; :type (or :subtype if field is a collection) needs to be an object with
    # the following fields if [:id, :exist?, :save!]. Stores the id instead of the whole object.

  def validate(value)
    validate_required(value)
    # type_ref validation happens during type/subtype checks
    validate_type(value)
    validate_subtypes(value)
  end

  def validate_def()
    ## TODO: add a check for a field def to throw an error if type/subtype aren't
    # set and type_ref == true. Also, type class should have following fields: [:id, :exist?, :save!]
  end

  def to_obj
    {
      'key' => key,
      'display_name' => display_name,
      'type' => type,
      'subtype' => subtype,
      'required' => required,
      'type_ref' => type_ref
    }
  end

  def self.from_obj(key, obj)
    field = Field.new
    field.key = key
    field.display_name = obj['display_name'] || obj[:display_name]
    field.type = Field.from_type(obj, 'type')
    field.subtype = Field.from_type(obj, 'subtype')
    field.required = Field.from_boolean(obj, 'required')
    field.type_ref = Field.from_boolean(obj, 'type_ref')
    field.validate_def
    return field
  end

  ###################################################################
  #                       HELPER METHODS                            #
  ###################################################################

  private

  def validate_required(value)
    return if !@required
    if (value.nil? || (value.respond_to?(:empty?) && value.empty?))
      raise ListError::Validation, "'#{@key}' is a required field and wasn't found"
    end
  end

  def validate_type(value)
    return if @type.nil?
    return if value.nil? 
    return if value.is_a?(@type)
    return if @subtype.nil? && type_ref_passes(value, @type)
    # Checking if it's a custom type from SchemaType
    return if @type.respond_to?(:type_match?) && @type.type_match?(value)
    # If it isn't nil or match a standard type or custom type, raise an error
    raise ListError::Validation, "'#{@key}' is expecting type '#{@type}' but found '#{value.class.to_s}'"
  end

  def validate_subtypes(value)
    return if @subtype.nil?
    if value.respond_to?(:has_key?)
      value.each { |k,v| validate_subtype(v, k) }
    elsif value.respond_to?(:each)
      value.each { |v| validate_subtype(v) }
    end
  end

  def validate_subtype(value, hash_key = nil)
    return if value.nil?
    return if value.is_a?(@subtype)
    return if @subtype.respond_to?(:type_match?) && @subtype.type_match?(value)
    return if type_ref_passes(value, @subtype)
    message = "'#{@key}' is expecting a collection containing "
    message += "type refs of ids or objects for " if @type_ref
    message += "'#{@subtype}' types but found '#{value.class.to_s}'"
    message += " at '#{hash_key}'" if !hash_key.nil?
    raise ListError::Validation, message
  end

  def type_ref_passes(value, value_type)
    return @type_ref && value_type.respond_to?(:exist?) && value_type.exist?(value)
  end

  def self.from_type(obj, field_name)
    value = obj[field_name] || obj[field_name.to_sym]
    value = Module.const_get(value) if value.is_a?(String)
    return value
  end

  def self.from_boolean(obj, field_name)
    value = obj[field_name] || obj[field_name.to_sym]
    value = false if value.nil? && (obj[field_name] == false || obj[field_name.to_sym] == false)
    return value
  end

end