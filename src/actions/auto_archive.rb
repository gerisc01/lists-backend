require 'date'
require_relative '../type/item'
require_relative '../type/list'
require_relative '../type/item_group'
require_relative '../type/status'
require_relative '../type/placement'
require_relative './set_status'
require_relative './resolve_open_instance'

# Marks a one-off `completed` once all its placements are resolved. A one-off is an item in no list
# (item_has_shelf_home? is false). An untouched past placement blocks it.
def maybe_auto_archive(item_id, as_of_date: Date.today.iso8601, actor_id: nil)
  item = Item.get(item_id)
  return nil if item.nil?

  # A group member counts as a one-off here; see archivable_group_member?.
  return if item_has_shelf_home?(item_id) && !archivable_group_member?(item)
  return if Status.done?(item.json['status'])

  # An instance is resolved after its first session; close_instance ends it instead.
  return if !item.parent.nil?

  placements = Placement.for_item(item_id)
  return if placements.empty?
  return if !placements.all?(&:resolved?)

  return set_status(item_id, 'completed', actor_id)
end

# A group member's placements are finite like a one-off's, though item_has_shelf_home? answers for
# its group. Excludes instances, members whose template mints instances, and members also in a list.
def archivable_group_member?(item)
  return false if !item.parent.nil?
  return false if !instance_template_for(item).nil?
  return false if List.list.any? { |l| (l.items || []).include?(item.id) }

  return ItemGroup.for_members([item.id]).any?
end

# Also true when the item's parent, or a group containing it or its parent, is in a list — neither
# puts the item's own id in `list.items`.
def item_has_shelf_home?(item_id)
  item = Item.get(item_id)
  ids = [item_id]
  ids << item.parent if !item.nil? && !item.parent.nil?
  homes = ids + ItemGroup.for_members(ids).map(&:id)
  return List.list.any? { |l| (homes & (l.items || [])).any? }
end
