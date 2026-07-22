require_relative '../type/placement'

# Bind a placement to a day: the spine move of Phase 2. Flips a placement
# floating -> dated by setting its date and clearing the floating flag — one
# entity, two states (see docs/DECISIONS.md). Addressed by placement id because a
# floating placement has no (item, date) natural key to look it up by.
# Server-authoritative primitive, registry-registered, fronted by a thin endpoint.
# Re-binding an already-dated placement to a new date is just a re-date.
def bind_placement(placement_id, date)
  raise ListError::BadRequest, "a date is required" if date.to_s.empty?

  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  placement.date = date
  placement.floating = false
  placement.validate
  placement.save!
  placement
end
