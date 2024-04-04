require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'

require_relative './item'
require_relative './tag'
require_relative './template'

class ItemGroup

  schema = Schema.new
  schema.key = "item-group"
  schema.display_name = "Item Group"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'name', :required => false, :type => String, :display_name => 'Name'},
    {:key => 'group', :required => true, :type => Array, :subtype => Item, :type_ref => true, :display_name => 'Grouped Items'}
  ]
  apply_schema schema

  def add_template(template)
    self.group.each do |item_id|
      it = Item.get(item_id)
      it.add_template(template)
      it.save!
    end
  end

  def remove_template(template)
    self.group.each do |item_id|
      it = Item.get(item_id)
      it.remove_template(template)
      it.save!
    end
  end

end