class SchemaType
  class Dropdown

    def self.field_def_validation(field)
      extra_attrs = field.extra_attrs ? field.extra_attrs : {}
      if extra_attrs[:static_options].nil? && extra_attrs[:list_options].nil?
        raise Schema::ValidationError.new("Field must have either static_options or list_options")
      end
      if extra_attrs[:static_options] && extra_attrs[:list_options]
        raise Schema::ValidationError.new("Field cannot have both static_options and list_options")
      end
      if extra_attrs[:static_options] && !extra_attrs[:static_options].is_a?(Array)
        raise Schema::ValidationError.new("Field static_options must be an Array")
      end
      if extra_attrs[:list_options]
        list_id = extra_attrs[:list_options]
        list = List.get(list_id)
        raise Schema::ValidationError.new("Invalid list_options: List '#{list_id}' cannot be found") unless list
      end
    end

    def self.field_value_validation(field, value)
      extra_attrs = field.extra_attrs ? field.extra_attrs : {}
      unless extra_attrs[:list_options].nil?
        list = List.get(extra_attrs[:list_options])
        return true if list && list.items.include?(value)
      end
      unless extra_attrs[:static_options].nil?
        return true if extra_attrs[:static_options].include?(value)
      end
      raise Schema::ValidationError.new("Invalid value: #{value}")
    end

    def self.type_match?(value)
      value.is_a?(String) || value.is_a?(Integer)
    end

  end
end