require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../exceptions'
require_relative '../storage'

## Template rules
# - An item added to a list must meet the templates requirements
# - An item removed from a list will keep the template reference
# - When a template is deleted, the template reference will be deleted from all items in the collection

## TODO: This one isn't working yet
# - an item moved to a list must meet the templates requirements

class Template

    schema = Schema.new
    schema.key = "template"
    schema.display_name = "Template"
    schema.storage = TypeStorage.global_storage
    schema.accessors = [:get, :list, :exist?, :save!, :delete!]
    schema.fields = [
      {:key => 'key', :required => true, :type => String, :display_name => 'Key'},
      {:key => 'display_name', :required => true, :type => String, :display_name => 'Display Name'},
      {:key => 'fields', :required => true, :type => Array, :subtype => Field, :display_name => 'Fields'},
      {:key => 'highlight_fields', :required => false, :type => Array, :display_name => 'Highlighted Fields'},
      {:key => 'attributes', :required => false, :type => Hash, :display_name => 'Attributes'}
    ]
    apply_schema schema

    # Fix template fields to allow hash definitions but convert to Field objects before running validation
    alias_method(:original_fields=, :fields=)
    def fields=(values)
        if values.is_a?(Array)
            transformed_values = values.map do |field_val|
                if field_val.is_a?(Field)
                    field_val
                elsif field_val.is_a?(Hash) && field_val.key?('key')
                    Field.from_schema_object(field_val['key'], field_val)
                elsif field_val.is_a?(Hash) && field_val.key?(:key)
                    Field.from_schema_object(field_val[:key], field_val)
                else
                    raise Schema::ValidationError, "Invalid field definition in template: #{field_val.inspect}"
                end
            end
            self.original_fields = transformed_values
        else
            self.original_fields = values
        end
    end

    attr_accessor :validator_schema

    def validate_obj(value)
        if validator_schema.nil? || validator_schema.empty?
            validator_schema = Schema.new
            validator_schema.key = self.key
            validator_schema.display_name = self.display_name
            validator_schema.fields = self.fields.map do |field|
                ## Set type and subtype to empty if they are Template
                field.type = nil if field.type == Template
                field.subtype = nil if field.subtype == Template
                field
            end
            template_fields = self.fields.select { |field| field.type == Template || field.subtype == Template }
            validate_template_fields(template_fields, value)
        end
        validator_schema.validate(value)
    end

    def validate_template_fields(fields, value)
        fields.each do |field|
            begin
                field_value = value.json[field.key]
                next if field_value.nil?
                if field.type == Template
                    validate_template_field(field, field_value)
                elsif field.type == Array && field.subtype == Template
                    field_value.each { |it| validate_template_field(field, it) }
                elsif field.type == Hash && field.subtype == Template
                    field_value.each { |key, it| validate_template_field(field, it) }
                end
            rescue Schema::ValidationError => e
                raise Schema::ValidationError, "Invalid Sub-Template (field: #{field.key}): #{e.message}"
            end
        end
    end

    def validate_template_field(field, field_value)
        template = Template.get(field.extra_attrs[:template_id])
        unless field_value.is_a?(Hash)
            raise Schema::ValidationError, "Invalid Sub-Template (field: #{field.key}): Must be a Hash"
        end
        template.validate_obj(DummyItem.new(field_value))
    end

end

class DummyItem
    attr_accessor :json

    def initialize(input)
        @json = input
    end
end
