require_relative '../type/placement'

# The only writer of `priority`, so the per-date cap is enforced here.
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
  return placement
end
