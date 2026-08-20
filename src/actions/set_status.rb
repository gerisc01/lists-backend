require_relative '../type/item'
require_relative '../type/status'
require_relative './resolve_open_instance'

# Server-authoritative lifecycle status change. The client supplies only the
# target status; the server owns `from`, the timestamp, and the append to the
# history log, so transitions can't be forged or skipped. A dedicated primitive,
# NOT a generic set_field (see docs/DECISIONS.md). Returns the updated item so the
# REST endpoint can hand it back for cache patching, and so it can be composed in
# later step-chained actions.
def set_status(item_id, status)
  unless Status::VALUES.include?(status)
    raise ListError::BadRequest, "Unknown status '#{status}'"
  end

  item = Item.get(item_id)
  raise ListError::NotFound, "item id '#{item_id}' not found" if item.nil?

  from = item.json['status'] || Status::DEFAULT
  item.json['status'] = status
  item.json['transitions'] ||= []
  item.json['transitions'] << Transition.build(from: from, to: status)

  item.validate
  item.save!

  # The third door into an instance (resolve_open_instance.rb): starting something
  # without planning it first. Flipping a repeat-tracked item to `doing` by hand opens
  # an instance, so the record does not depend on using the planner. Idempotent, and a
  # no-op both for items that never opted in and for the instance children themselves.
  resolve_open_instance(item_id) if status == 'doing' && from != 'doing'

  item
end
