require 'date'
require_relative '../type/item'
require_relative '../type/status'
require_relative './resolve_open_instance'
require_relative './set_status'

# Staging doesn't start an instance; its first completed session does: this stamps `started` and
# moves the instance and its item to doing. A `retired` item stays retired.
def start_instance_for(placement, actor_id = nil)
  instance = Item.get(placement.item_id)
  return nil if instance.nil?

  parent = instance.parent.nil? ? nil : Item.get(instance.parent)
  return nil if parent.nil?
  return if instance_template_for(parent).nil?

  # The session's own date, so logging it late still backdates the start.
  stamp_instance_start(instance, placement.date || Date.today.iso8601)

  advance_to_doing(instance.id, instance.json['status'], actor_id)
  return advance_to_doing(parent.id, parent.json['status'], actor_id)
end

def advance_to_doing(item_id, current_status, actor_id = nil)
  return if current_status == 'doing' || current_status == 'retired'
  return set_status(item_id, 'doing', actor_id)
end
