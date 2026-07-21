require_relative '../type/placement'

# Flag (or unflag) a dated placement as a priority — folds in the old
# Day.priorities concept. Preserves the per-date cap that a bounded priorities
# array gave for free: at most Placement::MAX_PRIORITIES_PER_DATE flagged
# placements on a date. Server-authoritative primitive; the cap lives here (the
# one write path for priority) rather than on the schema. Idempotent when the flag
# is already in the requested state.
def set_placement_priority(item_id, date, collection_id, priority)
  placement = Placement.find_dated(item_id, date, collection_id)
  raise ListError::NotFound, "no placement for item '#{item_id}' on '#{date}'" if placement.nil?

  priority = (priority == true)
  return placement if (placement.priority == true) == priority

  if priority
    flagged = Placement.for_date(date).count { |p| p.priority == true }
    if flagged >= Placement::MAX_PRIORITIES_PER_DATE
      raise ListError::BadRequest,
        "date '#{date}' already has the maximum of #{Placement::MAX_PRIORITIES_PER_DATE} priorities"
    end
  end

  placement.priority = priority
  placement.validate
  placement.save!
  placement
end
