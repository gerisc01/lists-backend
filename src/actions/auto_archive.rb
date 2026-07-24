require_relative '../type/item'
require_relative '../type/list'
require_relative '../type/status'
require_relative '../type/placement'
require_relative './set_status'

# Auto-archive for one-offs (design.md §2.2/§3, docs/DECISIONS.md "Archive = done +
# filtered + retained"). A one-off is a catalog item BORN ON THE BOARD WITH NO SHELF
# HOME — derived, not a stored flag: "an item in no list, referenced by a placement."
# Its placement set is finite and closed, so "all placements resolved" definitionally
# means nothing is left — a safe auto-archive, NOT the fragile roll-up inference the
# design bans for reusable multi-day work.
#
# PR 6 scope = COMPLETION-ONLY: a placement is "resolved" when `completed`. Event
# "past = resolved" and task "past carries" land in PR 9 (carry-forward/Skip), where
# past-handling actually lives. Archiving reuses set_status(item, 'completed') so the
# transition journal is appended — archive is a status transition, never a deletion.
def maybe_auto_archive(item_id)
  # Only board-born (one-off) items auto-archive. A shelf item (in any list) must NOT
  # archive when a placement completes — a `doing` game completing a session-placement
  # stays `doing`. Having a shelf home is the whole distinction (§2.2).
  return if item_has_shelf_home?(item_id)

  placements = Placement.for_item(item_id)
  return if placements.empty?
  return unless placements.all? { |p| p.completed == true }

  item = Item.get(item_id)
  return if item.nil?
  return if Status.done?(item.json['status'])  # already terminal — idempotent no-op

  set_status(item_id, 'completed')
end

# Does any list reference this item? (Sole-user scale — a full scan is fine, mirroring
# the Placement query helpers.)
def item_has_shelf_home?(item_id)
  List.list.any? { |l| (l.items || []).include?(item_id) }
end
