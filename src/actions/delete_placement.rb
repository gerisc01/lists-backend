require_relative '../type/placement'
require_relative '../type/item'
require_relative './auto_archive'

# By id, so it works on floating placements too (remove_from_date needs a date). Also deletes the
# item when it's a one-off with no placements left.
def delete_placement(placement_id)
  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  placement.delete!

  item = Item.get(placement.item_id)
  if item && !item_has_shelf_home?(item.id) && Placement.for_item(item.id).empty?
    item.delete!
  end

  return placement
end
