require 'date'
require_relative '../type/item'
require_relative '../type/status'
require_relative './resolve_open_instance'
require_relative './set_status'

# Ends a run: stamps `finished` and completes the instance and its item. Separate from completing a
# session, since a run has many sessions. The next stage mints a new instance.
def close_instance(instance_id, finished_date = nil, actor_id = nil)
  instance = Item.get(instance_id)
  raise ListError::NotFound, "item id '#{instance_id}' not found" if instance.nil?

  parent = instance.parent.nil? ? nil : Item.get(instance.parent)
  raise ListError::BadRequest, "item '#{instance_id}' is not an instance" if parent.nil?

  instance.json['finished'] = finished_date || Date.today.iso8601
  # A run with no recorded session starts the day it finished.
  instance.json['started'] ||= instance.json['finished']
  instance.validate
  instance.save!

  set_status(instance_id, 'completed', actor_id) if instance.json['status'] != 'completed'
  set_status(parent.id, 'completed', actor_id) if parent.json['status'] != 'completed'

  return instance
end
