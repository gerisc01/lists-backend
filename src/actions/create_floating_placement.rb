require_relative '../type/placement'

# Create a floating (dayless) Placement for (item, collection): a placement that
# lives in staging with no date yet. Sibling of assign_to_date; the floating
# counterpart of a dated placement. Binding it to a day later (bind_placement)
# just sets the date and clears the flag — one entity, two states. See
# docs/DECISIONS.md "Placement is a first-class type".
#
# Deduped on (item, collection): re-staging an item that already has a floating
# placement returns the existing one rather than piling up duplicates in staging.
# (The multi-session "one item, many floating placements" model is a later concern;
# for now one floating placement per item keeps the staging pile clean.)
def create_floating_placement(item_id, collection_id)
  raise ListError::NotFound, "item id '#{item_id}' not found" unless Item.exist?(item_id)
  raise ListError::NotFound, "collection id '#{collection_id}' not found" unless Collection.exist?(collection_id)

  existing = Placement.floating_for_collection(collection_id).find { |p| p.item_id == item_id }
  return existing unless existing.nil?

  placement = Placement.new({
    'item_id' => item_id,
    'collection_id' => collection_id,
    'date' => nil,
    'floating' => true,
  })
  placement.validate
  placement.save!
  placement
end
