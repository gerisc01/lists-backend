require 'date'
require_relative '../type/item'
require_relative '../type/placement'
require_relative '../type/scheduling'
require_relative './auto_archive'

# The one idempotent primitive that ages the board forward (design.md §2.2/§4.4,
# docs/DECISIONS.md "one reconcile primitive"). It does the three past-handling
# jobs that all key off "the day is over," in one safe-to-re-run pass:
#
#   1. Carry-forward — a lapsed dated *task* (undone, its day fully past) re-floats
#      ONCE: date cleared, floating set, `origin_date` preserved. It re-enters
#      staging as floating (§4.4) and the "carried N weeks" count is DERIVED from
#      origin_date, never incremented — so re-running never double-counts.
#   2. Past-resolution — an *event* whose day is past is resolved by derivation
#      (Placement#resolved?); nothing is written for it here.
#   3. Auto-archive-of-past — a one-off whose placement set is now all resolved
#      (past events + explicit completes/skips) archives, via maybe_auto_archive.
#
# Idempotency is structural, not a guard: carry re-floats (so a carried task no
# longer matches the dated-and-past scan), resolution/count are derived, and
# archive is a no-op once terminal. That is what lets a dumb hourly trigger (PR 9b)
# call this safely. Logic lives here; the trigger/endpoint are separate (like
# set_status). PURE + UNTRIGGERED in 9a — nothing calls it yet (shadow-first).
#
# `as_of_date` is injectable (defaults to today) so tests can drive "a week later"
# deterministically. Returns a summary of what changed this run.
def reconcile(as_of_date: Date.today.iso8601)
  carried = []

  # 1. Carry-forward lapsed dated tasks. Scan is fine at sole-user scale.
  Placement.list.each do |placement|
    next unless placement.past?(as_of_date)          # dated + day fully over
    next unless placement.resolution.nil?            # completed/skipped tasks don't carry
    item = Item.get(placement.item_id)
    next if item.nil?
    next unless Scheduling.task?(item)               # events resolve on past; only tasks carry
    next if item_has_shelf_home?(item.id)            # carry-forward is one-off-task-only (§4.2 #2)

    placement.origin_date ||= placement.date         # anchor the count on first carry (immutable after)
    placement.date = nil
    placement.floating = true
    placement.validate
    placement.save!
    carried << placement
  end

  # 2/3. Auto-archive one-offs whose sets are now fully resolved. maybe_auto_archive
  # is a cheap no-op for shelf items, still-open sets, and already-terminal items,
  # so sweeping every placed item is safe and idempotent. (Carried tasks from step 1
  # are now floating+open, so they correctly block their item's archive.)
  archived = Placement.list.map(&:item_id).uniq.map do |item_id|
    maybe_auto_archive(item_id, as_of_date: as_of_date)
  end.compact

  { 'carried' => carried.map(&:id), 'archived' => archived.map(&:id) }
end
