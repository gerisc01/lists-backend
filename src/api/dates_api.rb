require 'sinatra/base'
require_relative '../type/day'
require_relative './helpers/date_helpers'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  get '/api/dates/:day/:list/items' do
    raise ListError::BadRequest, "Path must contain both a date and a list id." if params['day'].to_s.empty? || params['list'].to_s.empty?
    day = Day.get(params['day'])

    result = []
    if !day.nil?
      list = day.items.find { |d| d.id == params['list'] }
      result = list.items if !list.nil?
    end
    status 200
    body result.to_json
  end

  # Get the items from a range of dates for a given list
  get '/api/dates/:list/items' do
    raise ListError::BadRequest, "Path must contain a list id." if params['list'].to_s.empty?
    raise ListError::BadRequest, "Query parameters must contain 'start' and 'end' dates." if params['start'].to_s.empty? || params['end'].to_s.empty?

    start_date = Date.parse(params['start'])
    end_date = Date.parse(params['end'])
    raise ListError::BadRequest, "'start' date must be before 'end' date." if start_date > end_date

    result = {}
    (start_date..end_date).each do |date|
      day = Day.get(date.to_s)
      if !day.nil?
        list = day.items.find { |d| d.id == params['list'] }
        result[date.to_s] = list.items if !list.nil?
      end
    end

    status 200
    body result.to_json
  end

  # Add an item to a given day and list
  post '/api/dates/:day/items' do
    raise ListError::BadRequest, "Path must contain a date." if params['day'].to_s.empty?
    list_id, item_id = DateHelpers.get_list_and_item_from_payload(request.body.read)
    day = DateHelpers.add_item_to_day(params['day'], list_id, item_id)
    status 200
    body day.to_schema_object.to_json
  end

  # Add a priority item to a given day and list
  post '/api/dates/:day/priority' do
    raise ListError::BadRequest, "Path must contain a date." if params['day'].to_s.empty?
    day = Day.get(params['day'])
    if day.nil?
      day = Day.new({
        'id' => params['day'],
      })
    end

    json = JSON.parse(request.body.read)
    raise ListError::BadRequest, "Request body must contain 'list' and 'item'." if !json.is_a?(Hash) || json['list'].to_s.empty? || json['item'].to_s.empty?
    raise ListError::NotFound, "List id '#{json['list']}' cannot be found" unless List.exist?(json['list'])

    day.priorities = [] if day.priorities.nil?
    daily_item = day.priorities.find { |d| d.id == json['list'] }
    if daily_item.nil?
      daily_item = DailyItem.new({
        'id' => json['list'],
        'items' => [json['item']]
      })
      day.add_prioritie(daily_item)
    else
      daily_item.add_item(json['item'])
    end
    day.save!

    status 200
    body day.to_schema_object.to_json
  end

  # Remove an item from a given day and list
  delete '/api/dates/:day/items' do
    raise ListError::BadRequest, "Path must contain a date." if params['day'].to_s.empty?
    list_id, item_id = DateHelpers.get_list_and_item_from_payload(request.body.read)
    day = DateHelpers.remove_item_from_day(params['day'], list_id, item_id)
    status 200
    body day.to_schema_object.to_json
  end

  # Remove a priority item from a given day and list
  delete '/api/dates/:day/priorities' do
    raise ListError::BadRequest, "Path must contain a date." if params['day'].to_s.empty?
    day = Day.get(params['day'])
    raise ListError::NotFound, "Day '#{params['day']}' cannot be found" if day.nil?

    json = JSON.parse(request.body.read)
    raise ListError::BadRequest, "Request body must contain 'list' and 'item'." if !json.is_a?(Hash) || json['list'].to_s.empty? || json['item'].to_s.empty?
    raise ListError::NotFound, "List id '#{json['list']}' cannot be found" unless List.exist?(json['list'])

    daily_item = day.priorities.find { |d| d.id == json['list'] }
    if !daily_item.nil?
      daily_item.remove_prioritie(json['item'])
      # Update the reference in the day
      day.priorities.map! { |d| d.id == json['list'] ? daily_item : d }
    end
    day.save!

    status 200
    body day.to_schema_object.to_json
  end

  # Update the priority items for a given day and list
  put '/api/dates/:day/:list/priorities' do
    raise ListError::BadRequest, "Path must contain both a date and a list id." if params['day'].to_s.empty? || params['list'].to_s.empty?
    day = Day.get(params['day'])
    raise ListError::NotFound, "List id '#{}' cannot be found" unless List.exist?(params['list'])

    if day.nil?
      day = Day.new({
        'id' => params['day'],
      })
    end

    json = JSON.parse(request.body.read)
    raise ListError::BadRequest, "Request body must be an array of item ids." if !json.is_a?(Array)

    day.priorities = [] if day.priorities.nil?
    priority_items = day.priorities.find { |d| d.id == params['list'] }
    if priority_items.nil?
      priority_items = DailyItem.new({
        'id' => params['list'],
        'items' => json
      })
      day.add_prioritie(priority_items)
    else
      # Update priority items and update the reference in the day
      priority_items.items = json
      day.priorities.map! { |p| p.id == params['list'] ? priority_items : p }
    end
    day.save!

    status 200
    body day.to_schema_object.to_json
  end

  #############################################################################
  #                       RECURRING DATE ENDPOINTS                            #
  #############################################################################
  # Add a new recurring date
  post '/api/dates/:day/recurring' do
    body = request.body.read
    list_id, item_id = DateHelpers.get_list_and_item_from_payload(body)
    # Expect the body to contain the recurring date definition
    json = JSON.parse(body)
    # Delete the list and item from the json to avoid duplication
    json.delete('list')
    json.delete('item')
    # Add the recurring date to the item to validate the definition
    item = ItemGeneric.get(item_id)
    if !item.json['recurring-parent'].nil? || !item.json['recurring-event'].nil?
      raise ListError::BadRequest, "Item id '#{item_id}' is already part of a recurring event."
    end
    DateHelpers.add_recurring_item_template(item)
    DateHelpers.update_items_recurring_data_and_create_children(params['day'], list_id, item, json)
    DateHelpers.add_item_to_day(params['day'], list_id, item_id)

    status 200
    body item.to_schema_object.to_json
  end

  # Modify an existing recurring date or convert a one-time date to recurring
  put '/api/dates/:day/recurring' do
    body = request.body.read
    list_id, item_id = DateHelpers.get_list_and_item_from_payload(body)
    # Expect the body to contain the recurring date definition
    json = JSON.parse(body)
    # Delete the list and item from the json to avoid duplication
    json.delete('list')
    json.delete('item')
    # Modify the recurring original recurring parent item and update the
    # new item to be the new recurring parent if needed
    item = ItemGeneric.get(item_id)
    recurring_parent = DateHelpers.get_parent_recurring_item(item)

    # If the item parent date is being changed, remove it from the old date and add it to the new date
    original_day = Day.get_days_for_item(item_id)[0]
    if params['day'] != original_day
      DateHelpers.remove_item_from_day(original_day, list_id, item_id)
      DateHelpers.add_item_to_day(params['day'], list_id, item_id)
    end

    if item_id != recurring_parent.id
      # Remove all children and day items from the recurring_parent starting from this item
      starting_index = recurring_parent.json['recurring-children'].index(item_id)
      DateHelpers.delete_items_and_remove_from_date(list_id, recurring_parent.json['recurring-children'][starting_index+1..-1]) if starting_index + 1 < recurring_parent.json['recurring-children'].length
      recurring_parent.json['recurring-children'] = recurring_parent.json['recurring-children'][0...starting_index]
      # Merge item.json and recurring_parent.json
      item.json = recurring_parent.json.merge(item.json)
      item.json['id'] = item.id
    else
      DateHelpers.delete_items_and_remove_from_date(list_id, recurring_parent.json['recurring-children'])
    end

    DateHelpers.update_items_recurring_data_and_create_children(params['day'], list_id, item, json)
    item.validate

    status 200
    body item.to_schema_object.to_json
  end

  # Delete a recurring date starting from a specific day
  delete '/api/dates/:day/recurring' do
    body = request.body.read
    list_id, item_id = DateHelpers.get_list_and_item_from_payload(body)
    item = ItemGeneric.get(item_id)
    recurring_parent = DateHelpers.get_parent_recurring_item(item)
    starting_index = item_id == recurring_parent.id ? 0 : recurring_parent.json['recurring-children'].index(item_id)
    # Assume recurring-children is in order of dates. Remove all children from start_index to end.
    DateHelpers.delete_items_and_remove_from_date(list_id, recurring_parent.json['recurring-children'][starting_index..-1])
    if item_id == recurring_parent.id
      recurring_parent.json.delete('recurring-event')
      recurring_parent.json.delete('recurring-children')
      DateHelpers.remove_item_from_day(params['day'], list_id, item_id)
    else
      recurring_parent.json['recurring-children'] = recurring_parent.json['recurring-children'][0...starting_index]
    end
    recurring_parent.save!

    status 200
    body recurring_parent.to_schema_object.to_json
  end

  #############################################################################
  #                     ITEM SPECIFIC DATE ENDPOINTS                          #
  #############################################################################
  # Get all dates for a specific item
  get '/api/items/:item/dates' do
    raise ListError::BadRequest, "Path must contain an item id." if params['item'].to_s.empty?
    dates = Day.get_days_for_item(params['item'])

    status 200
    body dates.to_json
  end

  #############################################################################
  #                     GENERATE SCHEMA CRUD METHODS                          #
  #############################################################################
  generate_schema_endpoint :list, 'dates', Day
  generate_schema_endpoint :get, 'dates', Day

end
