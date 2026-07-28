require_relative '../type/placement'

# Assign an item to a day: create a dated Placement for (item, date, collection).
# A dedicated server-authoritative primitive (sibling of set_status), fronted by a
# thin REST endpoint and registry-registered for composition. See docs/DECISIONS.md
# "Placement is a first-class type". Idempotent on the (item, date, collection)
# triple — re-assigning returns the existing placement rather than duplicating.
def assign_to_date(item_id, date, collection_id)
  raise ListError::NotFound, "item id '#{item_id}' not found" unless Item.exist?(item_id)
  raise ListError::NotFound, "collection id '#{collection_id}' not found" unless Collection.exist?(collection_id)
  raise ListError::BadRequest, "a date is required" if date.to_s.empty?

  existing = Placement.find_dated(item_id, date, collection_id)
  return existing unless existing.nil?

  placement = Placement.new({
    'item_id' => item_id,
    'collection_id' => collection_id,
    'date' => date,
    'floating' => false,
    # Immutable anchor for the carry-forward count — the original date this
    # instance was first placed on (see Placement#origin_date). Set once here.
    'origin_date' => date,
  })
  placement.validate
  placement.save!
  placement
end
