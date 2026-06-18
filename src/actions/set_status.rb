require_relative '../type/item'
require_relative '../type/status'

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
  item
end
