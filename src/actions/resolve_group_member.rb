require_relative '../type/item'
require_relative '../type/item_group'
require_relative '../type/status'

# An ItemGroup holds an ORDERED set of member items and occupies one row in a list —
# "the Yakuza series", "hang the pegboard". It is not an Item, lives in its own store,
# and can never carry a placement: a Placement's item_id always names an Item.
#
# This is the seam that lets you plan a group anyway. Staging a group means staging the
# member you would actually pick up, so the planner ends up holding "Yakuza 3", not "the
# Yakuza series". It is the mirror of resolve_open_instance: that one resolves UPWARD
# (a placement points at a run, and displays as its parent), this one resolves DOWNWARD
# (a row displays as the group, and stages as a member). They compose — the member
# returned here may itself resolve to an open instance.
#
# For anything that is not a group this returns item_id unchanged, which is what lets it
# sit on the staging path without altering any existing behavior.
def resolve_group_member(item_id)
  group = ItemGroup.get(item_id)
  return item_id if group.nil?

  member = group_next(group)
  if member.nil?
    raise ListError::BadRequest,
          "group '#{item_id}' has no member left to do — every member is finished, retired or on hold"
  end

  member.id
end

# The member you would pick up, and the same rule the frontend derives for the card
# (src/types/index.ts groupNext). A member that is already `doing` wins over an earlier
# untouched one: mid-Yakuza-3, "next" IS Yakuza 3, and preferring it is what keeps the
# group's derived status and the member it names from ever disagreeing.
#
# on-hold is skipped along with the terminal statuses — a deliberate pause is not what
# you would pick up.
def group_next(group)
  members = (group.group || []).map { |id| Item.get(id) }.compact
  members.find { |it| status_of(it) == 'doing' } ||
    members.find { |it| status_of(it) == 'want-to' }
end

# Absent status reads as the birth default, which is a live state — the default is
# deliberately never persisted (see Status::DEFAULT).
def status_of(item)
  item.json['status'] || Status::DEFAULT
end
