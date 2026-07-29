require_relative '../type/item'
require_relative '../type/collection'
require_relative '../type/placement'

# Turn a recurrence GHOST into a real Placement — the "touch => real" seam
# (design.md §2.5). Untouched occurrences are computed ghosts (occurrences.rb) with
# no id; the first time a user acts on one (binds it to a day, completes, skips,
# defers) it must become a persisted Placement so the existing id-addressed placement
# endpoints (bind/complete/skip/defer/delete) can drive it from there.
#
# The one load-bearing choice: stamp `origin_date = period_start` (the occurrence's
# due-week, from the ghost). That single field makes everything downstream consistent
# with NO Placement schema change:
#   * occurrences.rb dedup (occurrence_touched?) matches a persisted placement whose
#     origin_date's week == the due-week, so the ghost stops being emitted once
#     materialized — even if the user bound it to a day in a LATER week (the carried
#     case). Exact-match idempotency below works because we stamp period_start verbatim.
#   * "carried N weeks" (the staging badge, derived from origin_date) then measures
#     from when the occurrence was DUE — the correct recurring semantics.
#
# Sibling of assign_to_date / create_floating_placement (same guards + dedup style).
# REST-only, like reconcile — NOT registered in item_actions.rb (the registry invokes
# fixed positional param lists via ActionStep.process, and the optional `date` has no
# composition use yet). `date` nil => a floating placement in staging; a date =>
# dated straight onto that day.
def materialize_occurrence(item_id, collection_id, period_start, date = nil)
  raise ListError::NotFound, "item id '#{item_id}' not found" unless Item.exist?(item_id)
  raise ListError::NotFound, "collection id '#{collection_id}' not found" unless Collection.exist?(collection_id)
  raise ListError::BadRequest, "a period_start is required" if period_start.to_s.empty?

  # Idempotent on the occurrence: this item's placement already anchored to this
  # due-week represents it — re-materializing (a double-tap) returns it, never piles up.
  existing = Placement.for_item(item_id).find do |placement|
    placement.collection_id == collection_id && placement.origin_date == period_start
  end
  return existing unless existing.nil?

  dated = !date.to_s.empty?
  placement = Placement.new({
    'item_id' => item_id,
    'collection_id' => collection_id,
    'date' => (dated ? date : nil),
    'floating' => !dated,
    'origin_date' => period_start,
  })
  placement.validate
  placement.save!
  placement
end
