require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'

require_relative './item_generic'
require_relative './template'

class List

  schema = Schema.new
  schema.key = "list"
  schema.display_name = "List"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'name', :required => true, :type => String, :display_name => 'Name'},
    {:key => 'items', :required => false, :type => Array, :subtype => ItemGeneric, :type_ref => true, :display_name => 'Items'},
    {:key => 'template', :required => false, :type => Template, :type_ref => true, :display_name => 'Template'}
  ]
  apply_schema schema

  def add_item_with_template_ref(item)
    item.add_template(self.template) if !template.nil? || !template.empty?
    add_item(item)
  end

  def remove_item_with_template_ref(item)
    item.remove_template(self.template) if !template.nil? || !template.empty?
    remove_item(item)
  end

end