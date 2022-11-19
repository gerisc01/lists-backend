require_relative './custom_types'

class Field

  attr_accessor :key, :display_name, :type, :subtype, :required, :type_ref

  ## key:           unique identifying string with no spaces
  ## display_name:  a display name optionally used by downstream systems
  ## type:          name of a ruby class
  ## subtype:       name of a ruby class that is used for collection validation
  ## required:      boolean
  ## type_ref:      boolean; :type (or :subtype if field is a collection) needs to be an object with
    # the following fields if [:id, :exist?, :save!]. Stores the id instead of the whole object.

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
    validate_array_subtypes(value, self) if !value.nil? && @type == Array
    ## Hash subtype validation
    validate_hash_subtypes(value, self) if !value.nil? && @type == Hash
  end

  def validate_collection_element(value, field, hash_key = nil)
    # Type validation
    return if value.nil?
    if field.type_ref
      if !value.is_a?(String) && !value.is_a?(field.subtype) && !is_correct_custom_type(value, field.subtype)
        message = "'#{@key}' is expecting a collection containing type refs of ids or objects for '#{field.subtype}' types but found '#{value.class.to_s}'"
        message += " for hash key '#{hash_key}'" if !hash_key.nil?
        raise ValidationError, message
      end
    else
      if !value.is_a?(field.subtype) && !is_correct_custom_type(value, field.subtype)
        message = "'#{@key}' is expecting a collection containing '#{field.subtype}' types but found '#{value.class.to_s}'"
        message += " for hash key '#{hash_key}'" if !hash_key.nil?
        raise ValidationError, message
      end
    end
  end

  def validate_array_subtypes(array, field)
    array.each { |value| validate_collection_element(value, field) } if !subtype.nil?
  end

  def validate_hash_subtypes(hash, field)
    hash.each { |hkey, value| validate_collection_element(value, field, hkey) } if !subtype.nil?
  end

  def is_correct_custom_type(value, type)
    # If the type class is a subclass type of SchemaType and the type_match? matches the value
    return type.respond_to?(:type_match?) && type.type_match?(value)
  end

end