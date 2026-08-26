require 'date'
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
# "Resolved" is the full §2.3 rule (Placement#resolved?): an explicit completed/
# skipped resolution, OR an *event* whose day is past (a past task carries, so it
# is NOT resolved and blocks archive). Archiving reuses set_status(item,'completed')
# so the transition journal is appended — archive is a status transition, never a
# deletion. Returns the archived item (for reconcile to collect) or nil.
def maybe_auto_archive(item_id, as_of_date: Date.today.iso8601)
  # Only board-born (one-off) items auto-archive. A shelf item (in any list) must NOT
  # archive when a placement resolves — a `doing` game completing a session-placement
  # stays `doing`. Having a shelf home is the whole distinction (§2.2).
  return if item_has_shelf_home?(item_id)

  item = Item.get(item_id)
  return if item.nil?
  return if Status.done?(item.json['status'])  # already terminal — idempotent no-op

  # An INSTANCE (a playthrough) is list-free like a one-off, but its placement set is
  # NOT finite and closed: "all placements resolved" is true after the first completed
  # session, so a fourteen-session playthrough would archive itself in week one.
  #
  # The deeper reason is that this path cannot close an instance correctly even when the
  # count is right. It writes a status and nothing else, leaving an instance marked
  # completed with no `finished` date and a catalog item still sitting at `doing`.
  # Closing an instance is close_instance.rb's job, and it is explicit on purpose.
  return unless item.parent.nil?

  placements = Placement.for_item(item_id)
  return if placements.empty?
  return unless placements.all? { |p| p.resolved?(item, as_of_date: as_of_date) }

  set_status(item_id, 'completed')
end

# Does any list reference this item? (Sole-user scale — a full scan is fine, mirroring
# the Placement query helpers.)
def item_has_shelf_home?(item_id)
  List.list.any? { |l| (l.items || []).include?(item_id) }
end
