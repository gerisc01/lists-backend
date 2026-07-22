require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'
require_relative './item'
require_relative './collection'

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
    # Per-instance fields (fully exercised in later slices; defined now so the
    # entity is whole): did this instance happen, when, its actual time cost, a note.
    {:key => 'completed', :required => false, :type => SchemaType::Boolean, :display_name => 'Completed'},
    {:key => 'completed_at', :required => false, :type => String, :display_name => 'Completed At'},
    {:key => 'time_cost', :required => false, :type => Integer, :display_name => 'Time Cost'},
    {:key => 'note', :required => false, :type => String, :display_name => 'Note'},
  ]
  apply_schema schema

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
  # a day is addressed by its placement id.
  def self.floating_for_collection(collection_id)
    self.list.select { |p| p.collection_id == collection_id && p.floating == true && p.date.nil? }
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

  # The weekly-planning range read: { date => [item_ids] } for one collection across
  # a date range. Replaces the legacy Day-based GET /api/dates/:collection/items.
  def self.day_map_for_collection(collection_id, start_date, end_date)
    result = Hash.new { |h, k| h[k] = [] }
    for_date_range(start_date, end_date).each do |p|
      result[p.date] << p.item_id if p.collection_id == collection_id
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
