require_relative '../type/placement'

# Remove an item from a day: delete the dated Placement for (item, date,
# collection). Server-authoritative primitive (sibling of assign_to_date). Returns
# the deleted placement (or nil if there was none) so the caller can patch its
# cache. Idempotent — removing a placement that isn't there is a no-op.
def remove_from_date(item_id, date, collection_id)
  placement = Placement.find_dated(item_id, date, collection_id)
  return nil if placement.nil?

  placement.delete!
  placement
end
