require_relative '../type/placement'

# Returns nil when there's no such placement.
def remove_from_date(item_id, date, collection_id)
  placement = Placement.find_dated(item_id, date, collection_id)
  return nil if placement.nil?

  placement.delete!
  return placement
end
