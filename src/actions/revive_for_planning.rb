require_relative '../type/item'
require_relative '../type/status'
require_relative './set_status'

# Planning a finished item moves it back to want-to (not doing, which would start an instance).
# Reopening a placement doesn't call this.
def revive_for_planning(item_id, actor_id = nil)
  item = Item.get(item_id)
  return nil if item.nil?
  return if !Status.done?(item.json['status'])

  return set_status(item_id, 'want-to', actor_id)
end
