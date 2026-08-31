require 'date'
require_relative '../type/item'
require_relative '../type/placement'
require_relative '../type/scheduling'
require_relative './auto_archive'

# The one idempotent primitive that ages the board forward (design.md §2.2/§4.4,
# docs/DECISIONS.md "one reconcile primitive" + "Weekly planning is a weekly PLAN").
# The planner is a lean weekly plan, not a weekless backlog, so reconcile RELEASES the
# past instead of accumulating it, in one safe-to-re-run pass:
#
#   0. Prune orphaned placements — the item was deleted out from under them.
#   1. Release the past week — for anything left over from a week now behind us:
#        - a floating SHELF-item placement un-stages (delete): the item stays on its
#          shelf, which is its durable home, so nothing is lost.
#        - a one-off TASK left over from a week now behind us LAPSES: resolution :=
#          'lapsed' + resolved_at stamped. A one-off has no shelf to fall back to;
#          lapsing keeps the record (retained, for a future week report / pull-forward)
#          rather than deleting it. Events resolve by derivation (their past day =
#          resolved via Placement#resolved?), so they are not lapsed here.
#
#      THE WEEK, NOT THE DAY, on both arms. A task you meant to do Tuesday and didn't is
#      still this week's plan on Wednesday — move it to Friday. Closing it a day later
#      marked something undone as resolved (and auto-archived the item to `completed`),
#      which is the board telling you a thing you skipped is finished. See decision 0075.
#   2. Auto-archive one-offs whose sets are now fully resolved (past events + explicit
#      completes/skips + lapses), via maybe_auto_archive.
#
# Idempotency is structural: released shelf rows are gone, a lapsed placement is
# resolved (so it no longer matches the release scan), and archive is a no-op once
# terminal. A dumb hourly trigger can call this safely.
#
# `as_of_date` is injectable (defaults to today) so tests can drive "a week later"
# deterministically. The current week-start is the Monday of as_of_date, mirroring the
# frontend's Monday week-start (getStartOfWeek(date, 1)) that stamps staged_week.
# Returns a summary of what changed this run.
def reconcile(as_of_date: Date.today.iso8601)
  released = []
  lapsed = []
  current_week_start = monday_of(as_of_date)

  # 0. Prune orphaned placements — the item was deleted out from under them (design:
  #    the item is the source of truth, so a placement referencing a gone item isn't
  #    real). Do this first so the scans below never touch dead rows. Idempotent: once
  #    deleted the row is gone. Matches the read-side guard in floating_for_collection(s).
  pruned = Placement.list.select { |p| Item.get(p.item_id).nil? }
  pruned.each(&:delete!)

  # 1. Release the past week. Scan is fine at sole-user scale.
  Placement.list.each do |placement|
    next unless placement.resolution.nil?            # already-closed placements are done
    item = Item.get(placement.item_id)
    next if item.nil?

    floating_past = !placement.staged_week.nil? && placement.staged_week < current_week_start
    dated_past_week = !placement.date.nil? && placement.date < current_week_start

    if item_has_shelf_home?(item.id)
      # Shelf item: staged for a past week and untouched → un-stage back to its shelf.
      # (A dated past shelf placement is left as-is: it's out of the visible week already
      # and is raw material for a future week report.)
      if floating_past
        placement.delete!
        released << placement
      end
    elsif Scheduling.task?(item) && (floating_past || dated_past_week)
      # One-off task with no shelf home → lapse (retained). Events resolve by derivation.
      placement.resolution = 'lapsed'
      placement.resolved_at = Time.now.utc.iso8601
      placement.validate
      placement.save!
      lapsed << placement
    end
  end

  # 2. Auto-archive one-offs whose sets are now fully resolved. maybe_auto_archive is a
  # cheap no-op for shelf items, still-open sets, and already-terminal items, so
  # sweeping every placed item is safe and idempotent.
  archived = Placement.list.map(&:item_id).uniq.map do |item_id|
    maybe_auto_archive(item_id, as_of_date: as_of_date)
  end.compact

  {
    'released' => released.map(&:id),
    'lapsed' => lapsed.map(&:id),
    'archived' => archived.map(&:id),
    'pruned' => pruned.map(&:id),
  }
end

# The Monday (week-start) of a YYYY-MM-DD date, matching the frontend's Monday-based
# getStartOfWeek(date, 1) that stamps staged_week. wday: Sun=0..Sat=6; Ruby's % is
# non-negative, so Sunday (0) correctly maps back 6 days to the prior Monday.
def monday_of(iso_date)
  d = Date.parse(iso_date)
  (d - ((d.wday - 1) % 7)).iso8601
end
