require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'
require_relative './item'
require_relative './collection'
require_relative './resolution'
require_relative './scheduling'

# A Placement is one instance of an item being planned on a day (or floating,
# dayless, in staging). It REFERENCES the catalog item by id — never a copy — so
# one catalog item can carry many placements (multi-session, split-across-days)
# and edits/roll-up flow through. See docs/DECISIONS.md: "Placement is a first-class
# type (floating<->dated behind one flag); Day/DailyItem become a derived read".
#
# Floating vs dated is one flag on one entity: a floating placement has `date` nil
# and `floating` true; binding is simply "set date, clear floating" (PR 5c).
# `priority` folds in Day.priorities — a priority is just a dated placement that's
# flagged; the per-date cap is enforced by the set-priority primitive, not here.
class Placement

  # Max flagged priorities per date (preserves the old per-day priorities cap that
  # a bounded Day.priorities array gave for free). Enforced in set_placement_priority.
  MAX_PRIORITIES_PER_DATE = 3

  schema = Schema.new
  schema.key = "placement"
  schema.display_name = "Placement"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    # References, validated to exist at the type level via type_ref. (The action.rb
    # lazy-require fix keeps this from being a load-order cycle — see action.rb.)
    {:key => 'item_id', :required => true, :type => Item, :type_ref => true, :display_name => 'Item'},
    {:key => 'collection_id', :required => true, :type => Collection, :type_ref => true, :display_name => 'Collection'},
    # Placement location: a date (YYYY-MM-DD) OR floating (dayless). `date` nil +
    # `floating` true = floating; a date + `floating` false = dated.
    {:key => 'date', :required => false, :type => SchemaType::Date, :display_name => 'Date'},
    {:key => 'floating', :required => false, :type => SchemaType::Boolean, :display_name => 'Floating'},
    # A flagged (priority) placement — folds in Day.priorities.
    {:key => 'priority', :required => false, :type => SchemaType::Boolean, :display_name => 'Priority'},
    # How this instance was closed — `completed` | `skipped`, enforced by the
    # Resolution type; ABSENT = open (no sentinel). `resolved_at` is server-stamped
    # when a resolution is set (mirroring set_status's timestamp). A third,
    # `resolved?` is the predicate over it,
    # not stored. See docs/DECISIONS.md "placement resolution = completed|skipped".
    {:key => 'resolution', :required => false, :type => Resolution, :display_name => 'Resolution'},
    {:key => 'resolved_at', :required => false, :type => String, :display_name => 'Resolved At'},
    # WHO closed this instance — an account id, server-stamped from the request's
    # authenticated account alongside `resolved_at` and cleared on reopen. Never
    # client-supplied. Absent on every placement resolved before this field existed,
    # and on a resolution written without an account header, so a reader must treat
    # "unknown" as ordinary rather than as an error.
    {:key => 'resolved_by', :required => false, :type => String, :display_name => 'Resolved By'},
    # The ORIGINAL date this placement was first bound to — immutable, stamped on
    # first dating and never overwritten when carry-forward re-floats it. The
    # "carried N weeks" count (§4.4) is *derived* from this (elapsed weeks since
    # origin), never a stored counter, so the hourly reconcile trigger is idempotent.
    {:key => 'origin_date', :required => false, :type => SchemaType::Date, :display_name => 'Origin Date'},
    # The "not before week X" marker (legacy Defer, design §4.4). VESTIGIAL as of the
    # weekly-plan reframe (docs/DECISIONS.md): staged_week is now the single week
    # anchor and Defer moves it forward, so nothing writes not_before anymore. Field
    # kept so old rows validate; safe to drop in a later cleanup.
    {:key => 'not_before', :required => false, :type => SchemaType::Date, :display_name => 'Not Before'},
    # The week (Monday week-start, YYYY-MM-DD) a FLOATING placement is staged into
    # (docs/DECISIONS.md "Weekly planning is a weekly PLAN"). The planner is a lean
    # weekly plan, not a weekless backlog: the staging pile reads only placements
    # whose staged_week == the visible week. Stamped on stage (current week),
    # re-stamped on re-stage, and moved +1 week by Defer. Irrelevant once dated (a
    # dated placement is scoped by its date). reconcile releases placements whose
    # staged_week is behind the current week.
    {:key => 'staged_week', :required => false, :type => SchemaType::Date, :display_name => 'Staged Week'},
    {:key => 'time_cost', :required => false, :type => Integer, :display_name => 'Time Cost'},
    {:key => 'note', :required => false, :type => String, :display_name => 'Note'},
    # WHO is doing this instance — an account id, absent when nobody has claimed it.
    # Per-INSTANCE on purpose: a chore two people alternate weeks on would otherwise
    # overwrite one field forever, losing whose turn each week was. Assignment is a
    # display and planning axis, never a permission one — an assignee restricts
    # nothing, and everyone in the collection stays a peer (design §6.1).
    {:key => 'assignee', :required => false, :type => String, :display_name => 'Assignee'},
  ]
  apply_schema schema

  # ── Resolution (per design §2.3/§4.4) ────────────────────────────────────────
  # Is this placement closed? Only an explicit resolution (completed/skipped/lapsed)
  # closes one. Nothing is ever resolved by the passage of time.
  #
  # It used to take `(item, as_of_date:)` because a past *event* resolved by derivation
  # while a past *task* did not. The event kind is gone (decision 0076) and with it the
  # only reason this was ever more than a nil check — but the name stays, because
  # auto_archive and reconcile both read it and "is this closed" is the question they ask.
  def resolved?
    !resolution.nil?
  end

  # A dated placement whose day is fully past (strictly before as_of_date — the
  # "day is over" boundary; the same day is still live). Floating placements have
  # no day, so they are never "past".
  def past?(as_of_date)
    !date.nil? && date < as_of_date
  end

  # The CATALOG item this placement belongs to. `item_id` may name an INSTANCE child —
  # one playthrough of a game — in which case identity (the name on the card, the tags,
  # whether it has a list home) belongs to the parent, while the placement itself is
  # correctly addressed to the instance.
  #
  # DERIVED on every read from item.parent rather than stored as a second pointer on the
  # placement. Two stored pointers to the same relationship can drift apart; one cannot.
  def catalog_item_id
    item = Item.get(item_id)
    return item_id if item.nil?
    item.parent.nil? ? item_id : item.parent
  end

  # The client-facing shape: the stored placement plus the derived identity above. Every
  # read that a card renders from goes through this, so no caller has to know that
  # `item_id` might name an instance.
  def to_client_object
    to_schema_object.merge('catalog_item_id' => catalog_item_id)
  end

  # ── Queries (indexed by date and by item; scans the store, which is fine at this
  # app's scale — a sole-user planner) ────────────────────────────────────────────

  def self.for_item(item_id)
    self.list.select { |p| p.item_id == item_id }
  end

  def self.for_date(date)
    self.list.select { |p| p.date == date }
  end

  # Floating (dayless) placements for one collection — the staging pile for that
  # collection. Returns full placements (not just item_ids) because binding one to
  # a day is addressed by its placement id. Orphaned placements (whose item was
  # deleted out from under them) are excluded: a placement is only real if its item
  # still exists — `Item.get` returns nil for a soft-deleted item. reconcile prunes
  # the dead rows for good; this read keeps them out until it does.
  def self.floating_for_collection(collection_id)
    self.list.select do |p|
      p.collection_id == collection_id && p.floating == true && p.date.nil? &&
        !Item.get(p.item_id).nil?
    end
  end

  # Floating (dayless) placements across a SET of collections for ONE week — the
  # cross-collection staging pile (PR 8), now week-scoped (docs/DECISIONS.md "Weekly
  # planning is a weekly PLAN"). Returns only placements staged for `week_start` and
  # still OPEN (resolution nil): the planner is this-week's plan, so other weeks and
  # resolved placements don't surface. Deferred placements appear for free — Defer
  # just moves staged_week forward, so they match once their week arrives. One scan;
  # the caller groups by collection_id. Same orphan-exclusion guard as before.
  #
  # `week_start` may be nil, in which case the scan falls back to all floating
  # placements (legacy/unfiltered) — callers that own a week always pass one.
  def self.floating_for_collections(collection_ids, week_start = nil)
    self.list.select do |p|
      collection_ids.include?(p.collection_id) && p.floating == true && p.date.nil? &&
        p.resolution.nil? &&
        (week_start.nil? || p.staged_week == week_start) &&
        !Item.get(p.item_id).nil?
    end
  end

  def self.for_date_range(start_date, end_date)
    self.list.select { |p| !p.date.nil? && p.date >= start_date && p.date <= end_date }
  end

  # The one dated placement for (item, date, collection), if any. Assignment is
  # idempotent on this triple.
  def self.find_dated(item_id, date, collection_id)
    self.list.find do |p|
      p.item_id == item_id && p.date == date && p.collection_id == collection_id
    end
  end

  # The weekly-planning range read: { date => [placements] } for one collection across
  # a date range. Replaces the legacy Day-based GET /api/dates/:collection/items.
  def self.day_map_for_collection(collection_id, start_date, end_date)
    result = Hash.new { |h, k| h[k] = [] }
    for_date_range(start_date, end_date).each do |p|
      result[p.date] << p.to_client_object if p.collection_id == collection_id
    end
    result
  end

  # The cross-collection weekly-planning range read (PR 8): { date => [placements] }
  # across a SET of collections. Keeps a placement's source collection provenance —
  # a card bound from any staged collection stays on the mixed grid.
  #
  # Returns FULL placement objects, not bare item_ids: the grid renders placements,
  # and needs both the id (to address a resolution write — "I did this") and the
  # resolution itself (a completed card stays on the day struck through, rather than
  # vanishing). Unlike the floating pile read, resolved placements are NOT filtered
  # out here — the week's board doubles as the record of what got done.
  def self.day_map_for_collections(collection_ids, start_date, end_date)
    result = Hash.new { |h, k| h[k] = [] }
    for_date_range(start_date, end_date).each do |p|
      result[p.date] << p.to_client_object if collection_ids.include?(p.collection_id)
    end
    result
  end

  # A Day-shaped view derived from placements: { collection_id => [item_ids] } for a
  # date, plus the flagged (priority) subset. This is what lets Day/DailyItem become
  # a derived read — PR 5a proves it matches the legacy Day read; 5b cuts over to it.
  def self.day_view(date)
    items = Hash.new { |h, k| h[k] = [] }
    priorities = Hash.new { |h, k| h[k] = [] }
    for_date(date).each do |p|
      items[p.collection_id] << p.item_id
      priorities[p.collection_id] << p.item_id if p.priority == true
    end
    { 'items' => items, 'priorities' => priorities }
  end

end
