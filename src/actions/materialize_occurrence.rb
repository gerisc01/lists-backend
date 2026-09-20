require_relative '../type/item'
require_relative '../type/collection'
require_relative '../type/placement'

# Turns a ghost into a Placement with `origin_date = period_start`, which is how occurrence_touched?
# stops emitting the ghost. Not in the action registry.
def materialize_occurrence(item_id, collection_id, period_start, date = nil, staged_week = nil)
  raise ListError::NotFound, "item id '#{item_id}' not found" if !Item.exist?(item_id)
  raise ListError::NotFound, "collection id '#{collection_id}' not found" if !Collection.exist?(collection_id)
  raise ListError::BadRequest, "a period_start is required" if period_start.to_s.empty?

  # Already materialized: return it, moving a floating one into the week it's staged into now.
  existing = Placement.for_item(item_id).find do |placement|
    placement.collection_id == collection_id && placement.origin_date == period_start
  end
  if !existing.nil?
    if existing.date.nil? && staged_week && existing.staged_week != staged_week
      existing.staged_week = staged_week
      existing.validate
      existing.save!
    end
    return existing
  end

  dated = !date.to_s.empty?
  placement = Placement.new({
    'item_id' => item_id,
    'collection_id' => collection_id,
    'date' => (dated ? date : nil),
    'floating' => !dated,
    'origin_date' => period_start,
    # A floating placement needs a week, or no pile shows it and reconcile never releases it.
    'staged_week' => (dated ? nil : (staged_week || period_start)),
  })
  placement.validate
  placement.save!
  return placement
end
