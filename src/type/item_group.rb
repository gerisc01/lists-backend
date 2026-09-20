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

  # Members have no pointer back to their group, so this scans every group.
  def self.for_members(item_ids)
    return [] if item_ids.empty?
    return self.list.select { |g| (g.group & item_ids).any? }
  end

  def add_template(template)
    self.group.each do |item_id|
      it = Item.get(item_id)
      next if it.nil?
      it.add_template(template)
      it.save!
    end
  end

  def remove_template(template)
    self.group.each do |item_id|
      it = Item.get(item_id)
      next if it.nil?
      it.remove_template(template)
      it.save!
    end
  end

end