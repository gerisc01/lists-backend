class SchemaType
  class RecurringDate

    VALID_TYPES = ['daily', 'weekly', 'monthly', 'yearly']

    def self.field_def_validation(field)
      if field.subtype == self
        raise Schema::ValidationError.new("SchemaType::RecurringDate can only be used as a field type, not a subtype")
      end
    end

    def self.field_value_validation(field, value)
      if !value.key?('interval') || !value['interval'].is_a?(Integer)
        raise Schema::ValidationError.new("Key 'interval' is required and must be an integer")
      end
      if !value.key?('type') || !value['type'].is_a?(String) || !VALID_TYPES.include?(value['type'].to_s.strip.downcase)
        raise Schema::ValidationError.new("Key 'type' is required and must be one of: [#{VALID_TYPES.join(', ')}]")
      end
    end

    def self.type_match?(value)
      value.is_a?(Hash)
    end

  end
end
