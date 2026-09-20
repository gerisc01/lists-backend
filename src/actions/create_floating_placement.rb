require_relative '../type/placement'
require_relative './resolve_open_instance'
require_relative './resolve_group_member'
require_relative './revive_for_planning'
require_relative '../type/item_generic'

# Re-staging an item with an open floating placement moves that placement to `staged_week` instead
# of adding one. A resolved placement doesn't count, so a lapsed one-off gets a new placement.
def create_floating_placement(item_id, collection_id, staged_week = nil, actor_id = nil)
  # A group id resolves to a member; a placement can only point at an Item.
  raise ListError::NotFound, "item id '#{item_id}' not found" if !ItemGeneric.exist?(item_id)
  item_id = resolve_group_member(item_id)
  raise ListError::NotFound, "item id '#{item_id}' not found" if !Item.exist?(item_id)
  raise ListError::NotFound, "collection id '#{collection_id}' not found" if !Collection.exist?(collection_id)

  # An instance-tracked item stages its open instance, so the dedupe below keys on the instance.
  item_id = resolve_open_instance(item_id)

  # After resolving the instance, so a finished run behind a fresh one stays completed.
  revive_for_planning(item_id, actor_id)

  existing = Placement.floating_for_collection(collection_id)
                      .find { |p| p.item_id == item_id && p.resolution.nil? }
  if !existing.nil?
    if staged_week && existing.staged_week != staged_week
      existing.staged_week = staged_week
      existing.validate
      existing.save!
    end
    return existing
  end

  placement = Placement.new({
    'item_id' => item_id,
    'collection_id' => collection_id,
    'date' => nil,
    'floating' => true,
    'staged_week' => staged_week,
  })
  placement.validate
  placement.save!
  return placement
end
