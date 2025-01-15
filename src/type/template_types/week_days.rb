class SchemaType
  class WeekDays

    DAYS = %w[M T W TH F SA SU]

    def self.field_def_validation(field)

    end

    def self.field_value_validation(field, value)
      value.each do |day|
        raise Schema::ValidationError.new("Invalid value: #{day}") unless DAYS.include?(day.to_s.upcase)
      end
    end

    def self.type_match?(value)
      value.is_a?(Array)
    end

  end
end