require_relative '../type/item'
require_relative '../type/item_group'
require_relative '../type/status'

# A placement can't point at a group, so planning a group plans the member you'd pick up next.
# Returns `item_id` unchanged when it isn't a group.
def resolve_group_member(item_id)
  group = ItemGroup.get(item_id)
  return item_id if group.nil?

  member = group_next(group)
  if member.nil?
    raise ListError::BadRequest,
          "group '#{item_id}' has no member left to do — every member is finished, retired or on hold"
  end

  return member.id
end

# Same rule as the frontend's groupNext (src/types/index.ts): the first doing member, else the first
# want-to. On-hold members are skipped.
def group_next(group)
  members = (group.group || []).map { |id| Item.get(id) }.compact
  return members.find { |it| status_of(it) == 'doing' } ||
    members.find { |it| status_of(it) == 'want-to' }
end

def status_of(item)
  return item.json['status'] || Status::DEFAULT
end
