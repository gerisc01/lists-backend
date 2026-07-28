require 'time'
require_relative '../type/placement'
require_relative '../type/resolution'
require_relative './auto_archive'

# Edit the per-instance fields of a placement — the note, the actual time cost
# this time, and how this instance was closed (`resolution`: completed | skipped,
# or nil to reopen). Addressed by placement id (a floating placement has no
# (item, date) key). Only these keys are writable here; identity/location (item,
# collection, date, floating, priority) move through their own primitives. When a
# resolution is set the server stamps `resolved_at` (mirroring how set_status owns
# its timestamp), and clears it on reopen. Unknown keys are ignored; an invalid
# resolution value is rejected by validation.
EDITABLE_PLACEMENT_FIELDS = %w[note time_cost resolution].freeze

def update_placement(placement_id, fields)
  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  fields = (fields || {}).slice(*EDITABLE_PLACEMENT_FIELDS)

  if fields.key?('resolution')
    resolution = fields['resolution']
    unless resolution.nil? || Resolution::VALUES.include?(resolution)
      raise ListError::BadRequest, "Unknown resolution '#{resolution}'"
    end
    placement.resolution = resolution                 # nil reopens (open again)
    placement.resolved_at = resolution.nil? ? nil : Time.now.utc.iso8601
  end
  placement.note = fields['note'] if fields.key?('note')
  placement.time_cost = fields['time_cost'] if fields.key?('time_cost')

  placement.validate
  placement.save!

  # Resolving a placement (completed OR skipped) can close a one-off's finite
  # placement set — auto-archive if so (no-op for shelf items and still-open sets).
  # Reopening (resolution:nil) never archives. See auto_archive.rb.
  maybe_auto_archive(placement.item_id) if fields.key?('resolution') && !fields['resolution'].nil?

  placement
end
