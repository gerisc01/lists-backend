require 'time'
require_relative '../type/placement'
require_relative '../type/resolution'
require_relative '../type/account'
require_relative '../type/item'
require_relative './auto_archive'
require_relative './start_instance'

# Other fields move through their own actions. `actor_id` is who made the request; resolved_by
# prefers the assignee, since people often tick off work someone else did.
EDITABLE_PLACEMENT_FIELDS = %w[note time_cost resolution assignee].freeze

def update_placement(placement_id, fields, actor_id = nil)
  placement = Placement.get(placement_id)
  raise ListError::NotFound, "placement id '#{placement_id}' not found" if placement.nil?

  fields = (fields || {}).slice(*EDITABLE_PLACEMENT_FIELDS)

  if fields.key?('resolution')
    resolution = fields['resolution']
    if !resolution.nil? && !Resolution::VALUES.include?(resolution)
      raise ListError::BadRequest, "Unknown resolution '#{resolution}'"
    end
    placement.resolution = resolution
    placement.resolved_at = resolution.nil? ? nil : Time.now.utc.iso8601
    # Stamped now so a later owner change doesn't rewrite it. May stay nil (e2e has no account).
    placement.resolved_by = resolution.nil? ? nil : (assignee_of(placement, fields) || actor_id)
  end
  if fields.key?('assignee')
    assignee = fields['assignee']
    # An unknown id would render as a blank chip.
    if !assignee.nil? && Account.get(assignee).nil?
      raise ListError::BadRequest, "Unknown assignee '#{assignee}'"
    end
    placement.assignee = assignee
  end
  placement.note = fields['note'] if fields.key?('note')
  placement.time_cost = fields['time_cost'] if fields.key?('time_cost')

  placement.validate
  placement.save!

  start_instance_for(placement, actor_id) if fields['resolution'] == 'completed'

  maybe_auto_archive(placement.item_id, actor_id: actor_id) if fields.key?('resolution') && !fields['resolution'].nil?

  return placement
end

# The assignee being written in this call, else the stored one, else the item's owner.
def assignee_of(placement, fields)
  assignee = fields.key?('assignee') ? fields['assignee'] : placement.assignee
  return assignee if !assignee.nil?
  return Item.get(placement.item_id)&.owner
end
