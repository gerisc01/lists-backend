require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'

require_relative './tag'
require_relative './template'
require_relative './item_generic'

class Item

  schema = Schema.new
  schema.key = "item"
  schema.display_name = "Item"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'name', :required => true, :type => String, :display_name => 'Name'},
    {:key => 'templates', :required => false, :type => Array, :subtype => Template, :type_ref => true, :set => true, :display_name => 'Template'},
    {:key => 'tags', :required => false, :type => Array, :subtype => Tag, :type_ref => true, :display_name => 'Tags'},
    {:key => 'parent', :required => false, :type => ItemGeneric, :type_ref => true, :display_name => 'Parent'},
    {:key => 'children', :required => false, :type => Array, :subtype => ItemGeneric, :type_ref => true, :display_name => 'Children'},
  ]
  apply_schema schema

  # Remove the old validate method and apply the new one that validates the schema and templates
  remove_method :validate if method_defined? :validate
  def validate
    self.class.schema.validate(self)
    unless self.templates.nil?
      self.templates.each do |template_id|
        t = Template.get(template_id)
        t.validate_obj(self)
      end
    end
  end

end
