require 'date'

class SchemaType

  class Boolean

    def self.type_match?(value)
      return value.is_a?(TrueClass) || value.is_a?(FalseClass)
    end

  end

  class Date

    def self.type_match?(value)
      begin
        return value.is_a?(::Date) || ::Date.parse(value)
      rescue
        return false
      end
    end

  end

end