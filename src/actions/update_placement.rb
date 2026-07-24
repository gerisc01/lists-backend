require 'time'
require_relative '../type/placement'
require_relative './auto_archive'

# Edit the per-instance fields of a placement — the note, the actual time cost
# this time, and whether this instance happened. Addressed by placement id (a
# floating placement has no (item, date) key). Only these three keys are writable
# here; identity/location (item, collection, date, floating, priority) move through
# their own primitives. When `completed` flips true the server stamps
# `completed_at` (mirroring how set_status owns its timestamp), and clears it when
# flipped false. Unknown keys are ignored.
EDITABLE_PLACEMENT_FIELDS = %w[note time_cost completed].freeze

def update_placement(placement_id, fields)
  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  fields = (fields || {}).slice(*EDITABLE_PLACEMENT_FIELDS)

  if fields.key?('completed')
    completed = (fields['completed'] == true)
    placement.completed = completed
    placement.completed_at = completed ? Time.now.utc.iso8601 : nil
  end
  placement.note = fields['note'] if fields.key?('note')
  placement.time_cost = fields['time_cost'] if fields.key?('time_cost')

  placement.validate
  placement.save!

  # Completing a placement can resolve a one-off's finite placement set — auto-archive
  # if so (no-op for shelf items and for still-open sets). See auto_archive.rb.
  maybe_auto_archive(placement.item_id) if fields.key?('completed') && fields['completed'] == true

  placement
end
