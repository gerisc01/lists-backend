require_relative '../type/placement'

# By id, since a floating placement has no date to look it up by. Also re-dates a dated one.
def bind_placement(placement_id, date)
  raise ListError::BadRequest, "a date is required" if date.to_s.empty?

  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  placement.date = date
  placement.floating = false
  placement.origin_date ||= date
  placement.validate
  placement.save!
  return placement
end
