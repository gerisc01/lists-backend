require 'sinatra/base'
require_relative '../type/day'
require_relative './helpers/date_helpers'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  get '/api/dates/:day/:collectionId/items' do
    raise ListError::BadRequest, "Path must contain both a date and a collection id." if params['day'].to_s.empty? || params['collectionId'].to_s.empty?
    day = Day.get(params['day'])

    result = []
    if !day.nil?
      day_collection_items = day.items.find { |d| d.id == params['collectionId'] }
      result = day_collection_items.items if !day_collection_items.nil?
    end
    status 200
    body result.to_json
  end

  get '/api/dates/:collectionId/items' do
    raise ListError::BadRequest, "Path must contain a collection id." if params['collectionId'].to_s.empty?
    raise ListError::BadRequest, "Query parameters must contain 'start' and 'end' dates." if params['start'].to_s.empty? || params['end'].to_s.empty?

    start_date = Date.parse(params['start'])
    end_date = Date.parse(params['end'])
    raise ListError::BadRequest, "'start' date must be before 'end' date." if start_date > end_date

    result = {}
    (start_date..end_date).each do |date|
      day = Day.get(date.to_s)
      if !day.nil?
        day_collection_items = day.items.find { |d| d.id == params['collectionId'] }
        result[date.to_s] = day_collection_items.items if !day_collection_items.nil?
      end
    end

    status 200
    body result.to_json
  end

  post '/api/dates/:day/items' do
    raise ListError::BadRequest, "Path must contain a date." if params['day'].to_s.empty?
    collection_id, item_id = DateHelpers.get_collection_and_item_from_payload(request.body.read)
    day = DateHelpers.add_item_to_day(params['day'], collection_id, item_id)
    item = ItemGeneric.get(item_id)
    did_update = DateHelpers.update_todo_item_date(item, params['day'])
    item.save! if did_update
    status 200
    body day.to_schema_object.to_json
  end

  post '/api/dates/:day/priority' do
    raise ListError::BadRequest, "Path must contain a date." if params['day'].to_s.empty?
    day = Day.get(params['day'])
    if day.nil?
      day = Day.new({
        'id' => params['day'],
      })
    end

    json = get_json_payload(request)
    raise ListError::BadRequest, "Request body must contain 'collection' and 'item'." if !json.is_a?(Hash) || json['collection'].to_s.empty? || json['item'].to_s.empty?
    raise ListError::NotFound, "Collection id '#{json['collection']}' cannot be found" if !Collection.exist?(json['collection'])

    day.priorities = [] if day.priorities.nil?
    daily_item = day.priorities.find { |d| d.id == json['collection'] }
    if daily_item.nil?
      daily_item = DailyItem.new({
        'id' => json['collection'],
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

  delete '/api/dates/:day/items' do
    raise ListError::BadRequest, "Path must contain a date." if params['day'].to_s.empty?
    collection_id, item_id = DateHelpers.get_collection_and_item_from_payload(request.body.read)
    day = DateHelpers.remove_item_from_day(params['day'], collection_id, item_id)
    item = ItemGeneric.get(item_id)
    did_update = DateHelpers.update_todo_item_date(item, nil)
    item.save! if did_update
    status 200
    body day.to_schema_object.to_json
  end

  delete '/api/dates/:day/priorities' do
    raise ListError::BadRequest, "Path must contain a date." if params['day'].to_s.empty?
    day = Day.get(params['day'])
    raise ListError::NotFound, "Day '#{params['day']}' cannot be found" if day.nil?

    json = get_json_payload(request)
    raise ListError::BadRequest, "Request body must contain 'collection' and 'item'." if !json.is_a?(Hash) || json['collection'].to_s.empty? || json['item'].to_s.empty?
    raise ListError::NotFound, "Collection id '#{json['collection']}' cannot be found" if !Collection.exist?(json['collection'])

    daily_item = day.priorities.find { |d| d.id == json['collection'] }
    if !daily_item.nil?
      daily_item.remove_prioritie(json['item'])
        day.priorities.map! { |d| d.id == json['collection'] ? daily_item : d }
    end
    day.save!

    status 200
    body day.to_schema_object.to_json
  end

  put '/api/dates/:day/:collectionId/priorities' do
    raise ListError::BadRequest, "Path must contain both a date and a collection id." if params['day'].to_s.empty? || params['collectionId'].to_s.empty?
    day = Day.get(params['day'])
    raise ListError::NotFound, "Collection id '#{params['collectionId']}' cannot be found" if !Collection.exist?(params['collectionId'])

    if day.nil?
      day = Day.new({
        'id' => params['day'],
      })
    end

    json = get_json_payload(request)
    raise ListError::BadRequest, "Request body must be an array of item ids." if !json.is_a?(Array)

    day.priorities = [] if day.priorities.nil?
    priority_items = day.priorities.find { |d| d.id == params['collectionId'] }
    if priority_items.nil?
      priority_items = DailyItem.new({
        'id' => params['collectionId'],
        'items' => json
      })
      day.add_prioritie(priority_items)
    else
        priority_items.items = json
      day.priorities.map! { |p| p.id == params['collectionId'] ? priority_items : p }
    end
    day.save!

    status 200
    body day.to_schema_object.to_json
  end

  post '/api/dates/:day/recurring' do
    body = request.body.read
    collection_id, item_id = DateHelpers.get_collection_and_item_from_payload(body)
    json = JSON.parse(body)
    json.delete('collection')
    json.delete('item')
    item = ItemGeneric.get(item_id)
    if !item.json['recurring-parent'].nil? || !item.json['recurring-event'].nil?
      raise ListError::BadRequest, "Item id '#{item_id}' is already part of a recurring event."
    end
    DateHelpers.add_recurring_item_template(item)
    DateHelpers.update_items_recurring_data_and_create_children(params['day'], collection_id, item, json)
    DateHelpers.add_item_to_day(params['day'], collection_id, item_id)
    DateHelpers.update_todo_item_date(item, params['day'])
    item.save!

    status 200
    body item.to_schema_object.to_json
  end

  # Also turns a one-time date into a recurring one.
  put '/api/dates/:day/recurring' do
    body = request.body.read
    collection_id, item_id = DateHelpers.get_collection_and_item_from_payload(body)
    json = JSON.parse(body)
    json.delete('collection')
    json.delete('item')
    # The edited item becomes the series' new parent.
    item = ItemGeneric.get(item_id)
    recurring_parent = DateHelpers.get_parent_recurring_item(item)

    original_day = Day.get_days_for_item(item_id)[0]
    if params['day'] != original_day
      DateHelpers.remove_item_from_day(original_day, collection_id, item_id)
      DateHelpers.add_item_to_day(params['day'], collection_id, item_id)
    end

    if item_id != recurring_parent.id
        starting_index = recurring_parent.json['recurring-children'].index(item_id)
      DateHelpers.delete_items_and_remove_from_date(collection_id, recurring_parent.json['recurring-children'][starting_index+1..-1]) if starting_index + 1 < recurring_parent.json['recurring-children'].length
      recurring_parent.json['recurring-children'] = recurring_parent.json['recurring-children'][0...starting_index]
        item.json = recurring_parent.json.merge(item.json)
      item.json['id'] = item.id
    elsif !recurring_parent.json['recurring-children'].nil?
      DateHelpers.delete_items_and_remove_from_date(collection_id, recurring_parent.json['recurring-children'])
    end

    DateHelpers.update_items_recurring_data_and_create_children(params['day'], collection_id, item, json)
    DateHelpers.update_todo_item_date(item, params['day'])
    item.validate
    item.save!

    status 200
    body item.to_schema_object.to_json
  end

  # Deletes the series from this day on.
  delete '/api/dates/:day/recurring' do
    body = request.body.read
    collection_id, item_id = DateHelpers.get_collection_and_item_from_payload(body)
    item = ItemGeneric.get(item_id)
    recurring_parent = DateHelpers.get_parent_recurring_item(item)
    starting_index = item_id == recurring_parent.id ? 0 : recurring_parent.json['recurring-children'].index(item_id)
    # recurring-children is in date order.
    DateHelpers.delete_items_and_remove_from_date(collection_id, recurring_parent.json['recurring-children'][starting_index..-1])
    if item_id == recurring_parent.id
      recurring_parent.json['recurring-event'] = nil
      recurring_parent.json['recurring-children'] = nil
      DateHelpers.remove_item_from_day(params['day'], collection_id, item_id)
      DateHelpers.update_todo_item_date(item, nil)
      item.save!
    else
      recurring_parent.json['recurring-children'] = recurring_parent.json['recurring-children'][0...starting_index]
      if recurring_parent.json['recurring-children'].empty?
        recurring_parent.json['recurring-event'] = nil
        recurring_parent.json['recurring-children'] = nil
      end
    end
    recurring_parent.save!

    status 200
    body recurring_parent.to_schema_object.to_json
  end

  get '/api/items/:itemId/dates' do
    raise ListError::BadRequest, "Path must contain an item id." if params['itemId'].to_s.empty?
    dates = Day.get_days_for_item(params['itemId'])

    status 200
    body dates.to_json
  end

  generate_schema_endpoint :list, 'dates', Day
  generate_schema_endpoint :get, 'dates', Day

end
