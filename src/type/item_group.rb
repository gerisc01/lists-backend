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

  # The groups claiming any of these item ids — the member -> group lookup, which the
  # schema has no back-pointer for (a member is an ordinary Item and knows nothing about
  # its group). Scans the store, like Placement's queries and for the same reason: this
  # is a sole-user catalog, and a derived read is what keeps the answer from going stale
  # when a group is renamed or a member moved out.
  #
  # The empty case short-circuits rather than falling through: the select would answer []
  # correctly anyway, but only after walking the whole store to do it.
  def self.for_members(item_ids)
    return [] if item_ids.empty?
    self.list.select { |g| (g.group & item_ids).any? }
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