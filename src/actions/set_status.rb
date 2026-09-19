require_relative '../type/item'
require_relative '../type/status'
require_relative './resolve_open_instance'

# The only writer of `status` and `transitions`. `actor_id` is nil when no person acted.
def set_status(item_id, status, actor_id = nil)
  if !Status::VALUES.include?(status)
    raise ListError::BadRequest, "Unknown status '#{status}'"
  end

  item = Item.get(item_id)
  raise ListError::NotFound, "item id '#{item_id}' not found" if item.nil?

  from = item.json['status'] || Status::DEFAULT
  item.json['status'] = status
  item.json['transitions'] ||= []
  item.json['transitions'] << Transition.build(from: from, to: status, by: actor_id)

  item.validate
  item.save!

  # A manual flip to doing opens and starts an instance, just like a first session.
  if status == 'doing' && from != 'doing'
    instance_id = resolve_open_instance(item_id)
    stamp_instance_start(Item.get(instance_id), Date.today.iso8601) if instance_id != item_id
  end

  return item
end
