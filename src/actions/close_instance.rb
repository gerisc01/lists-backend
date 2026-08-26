require 'date'
require_relative '../type/item'
require_relative '../type/status'
require_relative './resolve_open_instance'
require_relative './set_status'

# "I finished it." The one genuinely new user action in the instance loop, and
# deliberately separate from completing a session (✓ in the day view): a fourteen-session
# playthrough completes fourteen placements and closes ONE instance. Ending a session
# must never be able to end the run by accident, which is why this is its own primitive
# rather than a flag on the last resolution.
#
# Closing stamps `finished`, moves the instance to `completed`, and moves the catalog
# item with it. Once closed, the instance stops being the open one, so the next stage
# mints a fresh instance — that is the whole replay path.
def close_instance(instance_id, finished_date = nil)
  instance = Item.get(instance_id)
  raise ListError::NotFound, "item id '#{instance_id}' not found" if instance.nil?

  parent = instance.parent.nil? ? nil : Item.get(instance.parent)
  raise ListError::BadRequest, "item '#{instance_id}' is not an instance" if parent.nil?

  instance.json['finished'] = finished_date || Date.today.iso8601
  # An instance closed without ever having a session recorded still has a start: the day
  # it finished. Leaving it blank would render as an open-ended run in the ledger.
  instance.json['started'] ||= instance.json['finished']
  instance.validate
  instance.save!

  set_status(instance_id, 'completed') unless instance.json['status'] == 'completed'
  set_status(parent.id, 'completed') unless parent.json['status'] == 'completed'

  instance
end
