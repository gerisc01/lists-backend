require_relative './custom_types'

class Field

  attr_accessor :key, :display_name, :type, :subtype, :required

  ## key:           unique identifying string with no spaces
  ## display_name:  a display name optionally used by downstream systems
  ## type:          name of a ruby class
  ## subtype:       name of a ruby class that is used for collection validation
  ## required:      boolean

  def validate(value, type = @type)
    # Required validation
    if @required && (value.nil? || (value.respond_to?(:empty?) && value.empty?))
      raise ValidationError, "'#{@key}' is a required field and wasn't found"
    end
    # Type validation
    if (!value.nil? && !value.is_a?(@type)) && !is_correct_custom_type(value, @type)
      raise ValidationError, "'#{@key}' is expecting type '#{@type}' but found '#{value.class.to_s}'"
    end
    ## Array subtype validation
    validate_array_subtypes(value, @subtype) if !value.nil? && @type == Array
    ## Hash subtype validation
    validate_hash_subtypes(value, @subtype) if !value.nil? && @type == Hash
  end

  def validate_collection_element(value, subtype, hash_key = nil)
    # Type validation
    if (!value.nil? && !value.is_a?(subtype)) && !is_correct_custom_type(value, subtype)
      message = "'#{@key}' is expecting a collection containing '#{subtype}' types but found '#{value.class.to_s}'"
      message += " for hash key '#{hash_key}'" if !hash_key.nil?
      raise ValidationError, message
    end
  end

  def validate_array_subtypes(array, subtype)
    array.each { |value| validate_collection_element(value, subtype) } if !subtype.nil?
  end

  def validate_hash_subtypes(hash, subtype)
    hash.each { |hkey, value| validate_collection_element(value, subtype, hkey) } if !subtype.nil?
  end

  def is_correct_custom_type(value, type)
    # If the type class is a subclass type of SchemaType and the type_match? matches the value
    return type.respond_to?(:type_match?) && type.type_match?(value)
  end

end