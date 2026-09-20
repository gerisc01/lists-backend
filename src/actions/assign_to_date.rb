require_relative '../type/placement'
require_relative './resolve_open_instance'
require_relative './resolve_group_member'
require_relative './revive_for_planning'
require_relative '../type/item_generic'

# Returns the existing placement for (item, date, collection) instead of adding a second one.
def assign_to_date(item_id, date, collection_id, actor_id = nil)
  # A group id resolves to a member; a placement can only point at an Item.
  raise ListError::NotFound, "item id '#{item_id}' not found" if !ItemGeneric.exist?(item_id)
  item_id = resolve_group_member(item_id)
  raise ListError::NotFound, "item id '#{item_id}' not found" if !Item.exist?(item_id)
  raise ListError::NotFound, "collection id '#{collection_id}' not found" if !Collection.exist?(collection_id)
  raise ListError::BadRequest, "a date is required" if date.to_s.empty?

  item_id = resolve_open_instance(item_id)

  # After resolving the instance, so a finished run behind a fresh one stays completed.
  revive_for_planning(item_id, actor_id)

  existing = Placement.find_dated(item_id, date, collection_id)
  return existing if !existing.nil?

  placement = Placement.new({
    'item_id' => item_id,
    'collection_id' => collection_id,
    'date' => date,
    'floating' => false,
    'origin_date' => date,
  })
  placement.validate
  placement.save!
  return placement
end
