class Field

  attr_accessor :key, :display_name, :type, :required

  ## key:           unique identifying string with no spaces
  ## display_name:  a display name optionally used by downstream systems
  ## type:          name of a ruby class
  ## required:      boolean

  def validate(value)
    # Required validation
    if @required && (value.nil? || (value.respond_to?(:empty?) && value.empty?))
      raise ValidationError, "'#{@key}' is a required field and wasn't found"
    end
    # Type validation
    if !value.nil? && !value.is_a?(@type)
      raise ValidationError, "'#{@key}' is expecting type '#{@type}' but found '#{value.class.to_s}'"
    end
  end

end