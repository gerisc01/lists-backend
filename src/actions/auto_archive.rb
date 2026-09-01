require 'date'
require_relative '../type/item'
require_relative '../type/list'
require_relative '../type/item_group'
require_relative '../type/status'
require_relative '../type/placement'
require_relative './set_status'
require_relative './resolve_open_instance'   # instance_template_for — the run-keeping test

# Auto-archive for one-offs (design.md §2.2/§3, docs/DECISIONS.md "Archive = done +
# filtered + retained"). A one-off is a catalog item BORN ON THE BOARD WITH NO SHELF
# HOME — derived, not a stored flag: "an item in no list, referenced by a placement."
# Its placement set is finite and closed, so "all placements resolved" definitionally
# means nothing is left — a safe auto-archive, NOT the fragile roll-up inference the
# design bans for reusable multi-day work.
#
# "Resolved" means an explicit completed/skipped/lapsed resolution and nothing else — a
# day passing has never been evidence that you did the thing (0076), so an untouched past
# placement blocks archive. Archiving reuses set_status(item,'completed')
# so the transition journal is appended — archive is a status transition, never a
# deletion. Returns the archived item (for reconcile to collect) or nil.
def maybe_auto_archive(item_id, as_of_date: Date.today.iso8601)
  item = Item.get(item_id)
  return if item.nil?

  # Only board-born (one-off) items auto-archive. A shelf item (in any list) must NOT
  # archive when a placement resolves — a `doing` game completing a session-placement
  # stays `doing`. Having a shelf home is the whole distinction (§2.2).
  #
  # A group member is the exception, and it is not a weakening of that rule: it satisfies
  # the one-off test in substance and fails it only on a technicality (see
  # archivable_group_member?).
  return if item_has_shelf_home?(item_id) && !archivable_group_member?(item)
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
  return unless placements.all?(&:resolved?)

  set_status(item_id, 'completed')
end

# A group member archives like the one-off it substantively is: a step of "clean the
# garage" that you have checked off is finished, and saying so twice — once on the
# placement, once on the status dot — is the tax that made a group read `0 of 4` after a
# week of doing its work.
#
# It fails `item_has_shelf_home?` only because that helper (deliberately) answers for the
# GROUP's row, which is what stops reconcile lapsing a member and delete_placement
# deleting it. Both of those protect a member from being treated as board-born. Archive
# is the one door where board-born behavior is the RIGHT answer, because the reasoning
# behind it holds for a member exactly as written in §2.2: the placement set is finite
# and closed, so "all placements resolved" definitionally means nothing is left.
#
# Three exclusions, each removing a case where the placement set is NOT finite:
#
#   run-keeping     a member whose template mints instances is a series of sittings by
#                   declaration ("this is a game"). close_instance owns its ending
#   an instance     `parent` set — same reason, one level down (already guarded above,
#                   restated here so this predicate is true on its own)
#   its own row     a member that ALSO sits in a list is a shelf item in its own right,
#                   and the shelf rule applies to it unchanged
def archivable_group_member?(item)
  return false unless item.parent.nil?
  return false unless instance_template_for(item).nil?
  return false if List.list.any? { |l| (l.items || []).include?(item.id) }

  ItemGroup.for_members([item.id]).any?
end

# Does any list reference this item? (Sole-user scale — a full scan is fine, mirroring
# the Placement query helpers.)
#
# Two kinds of item are reachable from a list WITHOUT their own id appearing in
# `list.items`, and a bare id check reads both as list-free and therefore as board-born
# one-offs:
#
#   group member   only the GROUP id sits in `list.items`; members hang off its row
#   instance       a playthrough lives nowhere but on its parent, which is in the list
#
# Both are wrong at every caller, and progressively worse: the pile buckets the card
# under "One-offs"; reconcile LAPSES it instead of leaving it alone; auto_archive writes
# a status terminal; and delete_placement DELETES the item outright when you remove its
# last placement — losing a group member, or a whole run of a game.
#
# So the question is asked of everything this item is reachable THROUGH. One hop each
# way is enough, and they compose: a group cannot nest in a group, an instance cannot
# have an instance, but an instance's parent may well be a member of a group.
def item_has_shelf_home?(item_id)
  item = Item.get(item_id)
  ids = [item_id]
  ids << item.parent unless item.nil? || item.parent.nil?
  homes = ids + ItemGroup.for_members(ids).map(&:id)
  List.list.any? { |l| (homes & (l.items || [])).any? }
end
