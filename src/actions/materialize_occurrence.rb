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
def materialize_occurrence(item_id, collection_id, period_start, date = nil, staged_week = nil)
  raise ListError::NotFound, "item id '#{item_id}' not found" unless Item.exist?(item_id)
  raise ListError::NotFound, "collection id '#{collection_id}' not found" unless Collection.exist?(collection_id)
  raise ListError::BadRequest, "a period_start is required" if period_start.to_s.empty?

  # Idempotent on the occurrence: this item's placement already anchored to this
  # due-week represents it — re-materializing (a double-tap) returns it, never piles up.
  # A floating one re-stamps its staged_week, the same "re-staging means I want this
  # *this* week" rule create_floating_placement follows — otherwise touching a carried
  # occurrence from a later week strands the row in the week it was first materialized.
  existing = Placement.for_item(item_id).find do |placement|
    placement.collection_id == collection_id && placement.origin_date == period_start
  end
  unless existing.nil?
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
    # The pile is read per week (floating_for_collections filters on staged_week), so a
    # floating materialization MUST land in a week or it shows up in none of them and
    # reconcile can never release it. The caller passes the week it is being staged into
    # (the visible week, which for a carried occurrence is later than its due-week);
    # absent that, the occurrence's own due-week is the only week the server can infer.
    # A dated placement is scoped by its date and stays unstamped.
    'staged_week' => (dated ? nil : (staged_week || period_start)),
  })
  placement.validate
  placement.save!
  placement
end
