
require_relative '../../type/item'
require_relative '../../type/item_group'
require_relative '../../type/item_generic'

module DateHelpers

  ###############################################################################
  # Date Item Retrieval Helpers
  ###############################################################################
  def self.get_collection_and_item_from_payload(body)
    json = JSON.parse(body)
    raise ListError::BadRequest, "Request body must contain 'collection' and 'item'." if !json.is_a?(Hash) || json['collection'].to_s.empty? || json['item'].to_s.empty?
    raise ListError::NotFound, "Item id '#{json['item']}' cannot be found" unless ItemGeneric.exist?(json['item'])
    raise ListError::NotFound, "Collection id '#{json['collection']}' cannot be found" unless Collection.exist?(json['collection'])

    return json['collection'], json['item']
  end

  def self.get_parent_recurring_item(item)
    return item if item.json['recurring-parent'].nil? || !item.json['recurring-event'].nil?
    if !item.json['recurring-parent'].nil?
      parent_item = ItemGeneric.get(item.json['recurring-parent'])
      return parent_item if !parent_item.json['recurring-event'].nil?
    end
    raise ListError::BadRequest, "Item id '#{item.id}' is not a recurring item."
  end

  ###############################################################################
  # Date Single Item CRUD
  ###############################################################################

  def self.add_item_to_day(date, collection_id, item_id)
    day = Day.get(date)
    day = Day.new({ 'id' => date }) if day.nil?
    day.items = [] if day.items.nil?

    daily_item = day.items.find { |d| d.id == collection_id }
    if daily_item.nil?
      daily_item = DailyItem.new({ 'id' => collection_id, 'items' => [item_id] })
      day.add_item(daily_item)
    else
      daily_item.add_item(item_id)
    end
    day.save!
    Day.add_day_for_item(item_id, day.id)
    return day
  end

  def self.create_recurring_item(parent)
    # Create a new item each time because recurring items may want to track
    # their own completion status, notes, etc.
    item = Item.new({ 'name' => parent.name, 'recurring-parent' => parent.id })
    item.save!
    return item
  end

  def self.remove_item_from_day(date, collection_id, item_id)
    day = Day.get(date)
    raise ListError::NotFound, "Day '#{date}' cannot be found" if day.nil?
    daily_item = day.items.find { |d| d.id == collection_id }
    if !daily_item.nil?
      daily_item.remove_item(item_id)
      if daily_item.items.empty?
        # Remove the daily item if it has no more items
        day.items = day.items.reject { |d| d.id == collection_id }
      else
        # Update the reference if it still has items
        day.items = day.items.map { |d| d.id == collection_id ? daily_item : d }
      end
    end
    if day.items.to_a.empty? && day.priorities.to_a.empty?
      day.delete!
    else
      day.save!
    end
    Day.remove_day_for_item(item_id, day.id)
    return day
  end

  ###############################################################################
  # Date Multiple Items CRUD
  ###############################################################################

  def self.update_items_recurring_data_and_create_children(date, collection_id, item, recurring_event_spec)
    item.json['recurring-event'] = recurring_event_spec
    item.validate

    days = DateHelpers.find_recurring_event_days(date, recurring_event_spec)
    children_items = []
    days.each do |day|
      future_item = DateHelpers.create_recurring_item(item)
      children_items << future_item.id
      DateHelpers.add_item_to_day(day, collection_id, future_item.id)
    end
    item.json['recurring-children'] = children_items
    item.save!
  end

  def self.delete_items_and_remove_from_date(collection_id, items)
    items.each do |child_id|
      days = Day.get_days_for_item(child_id)
      days.each do |day|
        DateHelpers.remove_item_from_day(day, collection_id, child_id)
      end
      child_item = ItemGeneric.get(child_id)
      child_item.delete! unless child_item.nil?
    end
  end

  ###############################################################################
  # Date Recurring Event Helpers
  ###############################################################################

  def self.add_recurring_item_template(item)
    if !item.json['templates'] || !item.json['templates'].include?('recurring-item')
      item.json['templates'] = [] if item.json['templates'].nil?
      item.json['templates'] << 'recurring-item'
      item.validate
    end
  end

  def self.find_recurring_event_days(starting_day, recurring_event_spec)
    days = []
    interval = recurring_event_spec['interval']
    raise ListError::BadRequest, "Interval must be a valid integer" if !interval.is_a?(Integer) || interval <= 0
    if recurring_event_spec['type'] == 'weekly'
      current_day = Date.parse(starting_day)
      one_year_later = current_day.next_year(1)
      # Skip the first occurrence since it's the starting day
      current_day += interval * 7
      while current_day <= one_year_later
        days << current_day.to_s
        current_day += interval * 7
      end
    end
    return days
  end

end
