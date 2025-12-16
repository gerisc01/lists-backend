
require_relative '../../type/item'
require_relative '../../type/item_group'
require_relative '../../type/item_generic'

module DateHelpers

  def self.get_list_and_item_from_payload(body)
    json = JSON.parse(body)
    raise ListError::BadRequest, "Request body must contain 'list' and 'item'." if !json.is_a?(Hash) || json['list'].to_s.empty? || json['item'].to_s.empty?
    raise ListError::NotFound, "Item id '#{json['item']}' cannot be found" unless ItemGeneric.exist?(json['item'])
    raise ListError::NotFound, "List id '#{json['list']}' cannot be found" unless List.exist?(json['list'])

    return json['list'], json['item']
  end

  def self.get_parent_recurring_item(item)
    return item if item.json['recurring-parent'].nil? || !item.json['recurring-event'].nil?
    if !item.json['recurring-parent'].nil?
      parent_item = Item.get(item.json['recurring-parent'])
      return parent_item if !parent_item.json['recurring-event'].nil?
    end
    raise ListError::BadRequest, "Item id '#{item.id}' is not a recurring item."
  end

  def self.add_item_to_day(date, list_id, item_id)
    day = Day.get(date)
    day = Day.new({ 'id' => date }) if day.nil?
    day.items = [] if day.items.nil?

    daily_item = day.items.find { |d| d.id == list_id }
    if daily_item.nil?
      daily_item = DailyItem.new({ 'id' => list_id, 'items' => [item_id] })
      day.add_item(daily_item)
    else
      daily_item.add_item(item_id)
    end
    day.save!
    Day.add_day_for_item(item_id, day.id)
    return day
  end

  def self.remove_item_from_day(date, list_id, item_id)
    day = Day.get(date)
    raise ListError::NotFound, "Day '#{date}' cannot be found" if day.nil?
    daily_item = day.items.find { |d| d.id == list_id }
    if !daily_item.nil?
      daily_item.remove_item(item_id)
      if daily_item.items.empty?
        # Remove the daily item if it has no more items
        day.items = day.items.reject { |d| d.id == list_id }
      else
        # Update the reference if it still has items
        day.items = day.items.map { |d| d.id == list_id ? daily_item : d }
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

  def self.create_recurring_item(parent)
    # Create a new item each time because recurring items may want to track
    # their own completion status, notes, etc.
    item = Item.new({ 'name' => parent.name, 'recurring-parent' => parent.id })
    item.save!
    return item
  end

end
