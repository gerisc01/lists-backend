require_relative '../type/placement'
require_relative '../type/item'
require_relative './auto_archive'

# Delete a placement outright (design.md §4.4 Delete = "gone entirely") — the one
# genuinely destructive staging exit, in deliberate contrast to Skip (resolves) and
# archive (done + record retained, never deleted). Id-addressed like bind/update so it
# works on a floating placement (remove_from_date only covers dated placements by their
# (item, date, collection) key — it can't delete a floating one).
#
# For a BOARD-BORN ONE-OFF the item and its single floating placement are effectively
# one thing (design §2.2: a one-off is "an item in no list, referenced by a placement"),
# so "gone entirely" removes the orphan item too — but ONLY when the same guard
# auto_archive uses holds: no shelf home AND no other placements left. A shelf item, or
# an item with other placements, keeps the item; just this placement goes.
def delete_placement(placement_id)
  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  placement.delete!

  item = Item.get(placement.item_id)
  if item && !item_has_shelf_home?(item.id) && Placement.for_item(item.id).empty?
    item.delete!
  end

  placement
end
