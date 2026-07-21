require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'

require_relative './action'
require_relative './item_generic'
require_relative './template'
require_relative './sharing_scope'

class List

  schema = Schema.new
  schema.key = "list"
  schema.display_name = "List"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'name', :required => true, :type => String, :display_name => 'Name'},
    {:key => 'items', :required => false, :type => Array, :subtype => ItemGeneric, :type_ref => true, :display_name => 'Items'},
    {:key => 'template', :required => false, :type => Template, :type_ref => true, :display_name => 'Template'},
    {:key => 'actions', :required => false, :type => Array, :subtype => Action, :type_ref => true, :display_name => 'Actions'},
    {:key => 'attributes', :required => false, :type => Hash, :display_name => 'Attributes'},
    # Who can access this list (design §6.1). Structural only; absent reads as 'private'.
    {:key => 'sharing_scope', :required => false, :type => SharingScope, :display_name => 'Sharing Scope'}
  ]
  apply_schema schema

  def add_item_with_template_ref(item)
    if !template.nil? && !template.empty?
      item.add_template(self.template)
      item.validate
      item.save!
    end
    add_item(item)
  end

  def remove_item_with_template_ref(item)
    if !template.nil? && !template.empty?
      item.remove_template(self.template) if !template.nil? && !template.empty?
      item.save!
    end
    remove_item(item)
  end

end