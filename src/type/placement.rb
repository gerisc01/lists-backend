require 'ruby-schema'
require 'ruby-schema-storage'

require_relative '../storage'
require_relative './item'
require_relative './collection'
require_relative './resolution'
require_relative './scheduling'

# One planned session of an item, on a day or floating in staging. It points at the item by id,
# so one item can have many placements.
class Placement

  # Enforced in set_placement_priority, not by the schema.
  MAX_PRIORITIES_PER_DATE = 3

  schema = Schema.new
  schema.key = "placement"
  schema.display_name = "Placement"
  schema.storage = TypeStorage.global_storage
  schema.accessors = [:get, :list, :exist?, :save!, :delete!]
  schema.fields = [
    {:key => 'item_id', :required => true, :type => Item, :type_ref => true, :display_name => 'Item'},
    {:key => 'collection_id', :required => true, :type => Collection, :type_ref => true, :display_name => 'Collection'},
    # Floating: `date` nil and `floating` true. Dated: a date and `floating` false.
    {:key => 'date', :required => false, :type => SchemaType::Date, :display_name => 'Date'},
    {:key => 'floating', :required => false, :type => SchemaType::Boolean, :display_name => 'Floating'},
    {:key => 'priority', :required => false, :type => SchemaType::Boolean, :display_name => 'Priority'},
    # Absent means open. `resolved_at` and `resolved_by` are stamped when it's written.
    {:key => 'resolution', :required => false, :type => Resolution, :display_name => 'Resolution'},
    {:key => 'resolved_at', :required => false, :type => String, :display_name => 'Resolved At'},
    # The assignee at resolution, else the caller's account. Often absent — older rows, no header.
    {:key => 'resolved_by', :required => false, :type => String, :display_name => 'Resolved By'},
    # The first date it was bound to (or an occurrence's due week); never overwritten. "Carried N
    # weeks" is computed from it.
    {:key => 'origin_date', :required => false, :type => SchemaType::Date, :display_name => 'Origin Date'},
    # Nothing writes this; declared so stored rows that have it still validate.
    {:key => 'not_before', :required => false, :type => SchemaType::Date, :display_name => 'Not Before'},
    # The week start a floating placement is staged into; the pile shows only the visible week's.
    # Ignored once dated.
    {:key => 'staged_week', :required => false, :type => SchemaType::Date, :display_name => 'Staged Week'},
    {:key => 'time_cost', :required => false, :type => Integer, :display_name => 'Time Cost'},
    {:key => 'note', :required => false, :type => String, :display_name => 'Note'},
    # An account id. Display only; it restricts nothing.
    {:key => 'assignee', :required => false, :type => String, :display_name => 'Assignee'},
  ]
  apply_schema schema

  def resolved?
    !resolution.nil?
  end

  # Strictly before as_of_date; a floating placement is never past.
  def past?(as_of_date)
    return !date.nil? && date < as_of_date
  end

  # `item_id` may be an instance (one playthrough); this is the item the card is about.
  def catalog_item_id
    item = Item.get(item_id)
    return item_id if item.nil?
    return item.parent.nil? ? item_id : item.parent
  end

  def to_client_object
    return to_schema_object.merge('catalog_item_id' => catalog_item_id)
  end

  def self.for_item(item_id)
    return self.list.select { |p| p.item_id == item_id }
  end

  def self.for_date(date)
    return self.list.select { |p| p.date == date }
  end

  # Skips placements whose item was deleted (`Item.get` is nil); reconcile removes them later.
  def self.floating_for_collection(collection_id)
    return self.list.select do |p|
      p.collection_id == collection_id && p.floating == true && p.date.nil? &&
        !Item.get(p.item_id).nil?
    end
  end

  # Open placements only. A nil `week_start` returns every week's.
  def self.floating_for_collections(collection_ids, week_start = nil)
    return self.list.select do |p|
      collection_ids.include?(p.collection_id) && p.floating == true && p.date.nil? &&
        p.resolution.nil? &&
        (week_start.nil? || p.staged_week == week_start) &&
        !Item.get(p.item_id).nil?
    end
  end

  def self.for_date_range(start_date, end_date)
    return self.list.select { |p| !p.date.nil? && p.date >= start_date && p.date <= end_date }
  end

  # assign_to_date keeps this triple unique.
  def self.find_dated(item_id, date, collection_id)
    return self.list.find do |p|
      p.item_id == item_id && p.date == date && p.collection_id == collection_id
    end
  end

  def self.day_map_for_collection(collection_id, start_date, end_date)
    result = Hash.new { |h, k| h[k] = [] }
    for_date_range(start_date, end_date).each do |p|
      result[p.date] << p.to_client_object if p.collection_id == collection_id
    end
    return result
  end

  # Includes resolved placements, unlike the floating pile: the grid shows them struck through.
  def self.day_map_for_collections(collection_ids, start_date, end_date)
    result = Hash.new { |h, k| h[k] = [] }
    for_date_range(start_date, end_date).each do |p|
      result[p.date] << p.to_client_object if collection_ids.include?(p.collection_id)
    end
    return result
  end

  # { catalog_item_id => account_id }, only for items whose applicable placement names someone;
  # otherwise the client falls back to `item.owner`.
  def self.current_assignees_for_collections(collection_ids)
    in_scope = self.list.select { |p| collection_ids.include?(p.collection_id) }
    return in_scope.group_by(&:catalog_item_id).each_with_object({}) do |(item_id, placements), result|
      assignee = applicable_assignee(item_id, placements)
      result[item_id] = assignee if !assignee.nil?
    end
  end

  # Open placements → the soonest assignee. None open → nil if recurring, else the last resolved.
  def self.applicable_assignee(item_id, placements)
    open = placements.reject(&:resolved?)
    return soonest_assignee(open) if open.any?
    item = Item.get(item_id)
    return nil if !item.nil? && Scheduling.recurring?(item)
    return last_resolved(placements)&.assignee
  end

  # Floating placements sort after dated ones.
  def self.soonest_assignee(placements)
    return placements.sort_by { |p| [p.date.nil? ? 1 : 0, p.date.to_s] }
              .map(&:assignee)
              .compact
              .first
  end

  # By resolved_at (the date when it's missing), then by date — a batch of ticks shares a second.
  def self.last_resolved(placements)
    return placements.select(&:resolved?)
              .max_by { |p| [p.resolved_at.to_s.empty? ? p.date.to_s : p.resolved_at.to_s, p.date.to_s] }
  end

  # The placements for a date in the shape of a `Day` record.
  def self.day_view(date)
    items = Hash.new { |h, k| h[k] = [] }
    priorities = Hash.new { |h, k| h[k] = [] }
    for_date(date).each do |p|
      items[p.collection_id] << p.item_id
      priorities[p.collection_id] << p.item_id if p.priority == true
    end
    return { 'items' => items, 'priorities' => priorities }
  end

end
