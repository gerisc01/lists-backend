require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../exceptions'
require_relative '../storage'

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

    attr_accessor :validator_schema

    def validate_obj(value)
        if validator_schema.nil? || validator_schema.empty?
            validator_schema = Schema.new
            validator_schema.key = self.key
            validator_schema.display_name = self.display_name
            validator_schema.fields = self.fields
        end
        validator_schema.validate(value)
    end

end