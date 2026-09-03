require 'time'
require_relative '../type/placement'
require_relative '../type/resolution'
require_relative '../type/account'
require_relative '../type/item'
require_relative './auto_archive'
require_relative './start_instance'

# Edit the per-instance fields of a placement — the note, the actual time cost
# this time, who is doing it (`assignee`), and how this instance was closed
# (`resolution`: completed | skipped, or nil to reopen). Addressed by placement id
# (a floating placement has no (item, date) key). Only these keys are writable
# here; identity/location (item, collection, date, floating, priority) move through
# their own primitives. When a resolution is set the server stamps `resolved_at`
# and `resolved_by` (mirroring how set_status owns its timestamp), and clears both
# on reopen. Unknown keys are ignored; an invalid resolution value is rejected by
# validation.
#
# `actor_id` is the request's authenticated account, passed in by the route. It is
# NOT what `resolved_by` records: in a two-person household the person who taps the
# checkbox is routinely not the person who did the thing (you complete a chore for
# someone who is out), so the plan's answer is the better guess and the tap is the
# weaker signal (decision 0084). The actor is the fallback for work the plan never
# named, so that every resolution still carries a name.
EDITABLE_PLACEMENT_FIELDS = %w[note time_cost resolution assignee].freeze

def update_placement(placement_id, fields, actor_id = nil)
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
    # A STAMP, resolved once here and never re-derived: the owner it may have come
    # from can change later, and the past must not move with it (0083). Absent actor
    # AND absent assignee stays absent rather than erroring — an unauthenticated
    # write path (e2e) is still a legitimate resolution, just one with no name.
    placement.resolved_by = resolution.nil? ? nil : (assignee_of(placement, fields) || actor_id)
  end
  if fields.key?('assignee')
    assignee = fields['assignee']
    # Reject an id that names nobody — an assignee that resolves to no account would
    # render as a blank chip forever with no way to tell it from a display bug. nil
    # clears (nobody's doing it), which is the ordinary state, not an error.
    if !assignee.nil? && Account.get(assignee).nil?
      raise ListError::BadRequest, "Unknown assignee '#{assignee}'"
    end
    placement.assignee = assignee
  end
  placement.note = fields['note'] if fields.key?('note')
  placement.time_cost = fields['time_cost'] if fields.key?('time_cost')

  placement.validate
  placement.save!

  # A completed session is what STARTS an instance — stamping its date and moving the
  # catalog item to `doing`. Only `completed`: skipping a session is not doing it. A
  # no-op for any placement whose item is not an instance. See start_instance.rb.
  start_instance_for(placement) if fields['resolution'] == 'completed'

  # Resolving a placement (completed OR skipped) can close a one-off's finite
  # placement set — auto-archive if so (no-op for shelf items and still-open sets).
  # Reopening (resolution:nil) never archives. See auto_archive.rb.
  maybe_auto_archive(placement.item_id) if fields.key?('resolution') && !fields['resolution'].nil?

  placement
end

# Who the plan says is doing this placement: the override, else the item's owner.
# Reads the assignee being written in this same request when there is one, since the
# field is applied further down and a resolve-and-assign arrives as one call.
def assignee_of(placement, fields)
  assignee = fields.key?('assignee') ? fields['assignee'] : placement.assignee
  return assignee unless assignee.nil?
  Item.get(placement.item_id)&.owner
end
