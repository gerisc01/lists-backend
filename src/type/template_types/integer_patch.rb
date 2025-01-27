class Integer

  def self.field_def_validation(field)

  end

  def self.field_value_validation(field, value)
    return if value.is_a?(Integer)
    if value.is_a?(String)
      begin
        Integer(value)
      rescue ArgumentError
        raise Schema::ValidationError.new("Invalid value: #{value} is not an Integer")
      end
    end
  end

  def self.type_match?(value)
    value.is_a?(Integer) || value.is_a?(String)
  end

end