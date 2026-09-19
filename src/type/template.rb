require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../exceptions'
require_relative '../storage'
require_relative '../exceptions'
require_relative './reserved_fields'

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

    # Accepts hash field definitions and converts them to Field objects.
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

    # Ids of templates that another template names in `attributes.instances.template`.
    def self.instance_child_ids(excluding_id = nil)
        return list.filter_map do |template|
            next if template.id == excluding_id
            config = (template.attributes || {})['instances']
            config['template'] if config.is_a?(Hash)
        end
    end

    # An instance template can't drop INSTANCE_CONTRACT keys while another template points at it.
    remove_method :validate if method_defined? :validate
    def validate
        self.class.schema.validate(self)
        validate_no_system_keys
        return if !Template.instance_child_ids(self.id).include?(self.id)

        missing = ReservedFields::INSTANCE_CONTRACT - (self.fields || []).map(&:key)
        return if missing.empty?
        raise ListError::Validation,
              "Template '#{self.display_name}' keeps a record for another template, so it " \
              "cannot drop: #{missing.join(', ')}"
    end

    # A field with a reserved key would save and then never render.
    def validate_no_system_keys
        reserved = ReservedFields::SYSTEM_KEYS - ReservedFields::TEMPLATE_DECLARABLE
        taken = (self.fields || []).map(&:key) & reserved
        return if taken.empty?
        raise ListError::Validation,
              "Template '#{self.display_name}' uses a field key the app reserves: " \
              "#{taken.join(', ')}. Rename the field."
    end

    attr_accessor :validator_schema

    def validate_obj(value, visited = [])
        if validator_schema.nil?
            self.validator_schema = Schema.new
            validator_schema.key = self.key
            validator_schema.display_name = self.display_name
            validator_schema.fields = self.fields.map do |field|
                ## Set type and subtype to empty if they are Template
                field.type = nil if field.type == Template
                field.subtype = nil if field.subtype == Template
                field
            end
        end
        # Sub-templates are checked on every call: they validate the value, not the cached schema.
        template_fields = self.fields.select { |field| field.type == Template || field.subtype == Template }
        validate_template_fields(template_fields, value, visited + [self.id])
        return validator_schema.validate(value)
    end

    def validate_template_fields(fields, value, visited = [])
        fields.each do |field|
            begin
                field_value = value.json[field.key]
                next if field_value.nil?
                template_id = field.extra_attrs && field.extra_attrs[:template_id]
                next if template_id && visited.include?(template_id)
                if field.type == Template
                    validate_template_field(field, field_value, visited)
                elsif field.type == Array && field.subtype == Template
                    field_value.each { |it| validate_template_field(field, it, visited) }
                elsif field.type == Hash && field.subtype == Template
                    field_value.each { |key, it| validate_template_field(field, it, visited) }
                end
            rescue Schema::ValidationError => e
                raise Schema::ValidationError, "Invalid Sub-Template (field: #{field.key}): #{e.message}"
            end
        end
    end

    def validate_template_field(field, field_value, visited = [])
        template = Template.get(field.extra_attrs[:template_id])
        if !field_value.is_a?(Hash)
            raise Schema::ValidationError, "Invalid Sub-Template (field: #{field.key}): Must be a Hash"
        end
        return template.validate_obj(DummyItem.new(field_value), visited)
    end

end

class DummyItem
    attr_accessor :json

    def initialize(input)
        @json = input
    end
end
