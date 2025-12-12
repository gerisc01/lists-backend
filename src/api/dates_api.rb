require 'sinatra/base'
require_relative '../type/day'

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
    day = Day.get(params['day'])
    if day.nil?
      day = Day.new({
        'id' => params['day'],
      })
    end

    json = JSON.parse(request.body.read)
    raise ListError::BadRequest, "Request body must contain 'list' and 'item'." if !json.is_a?(Hash) || json['list'].to_s.empty? || json['item'].to_s.empty?
    raise ListkError::NotFound, "List id '#{json['list']}' cannot be found" unless List.exist?(json['list'])

    day.items = [] if day.items.nil?
    daily_item = day.items.find { |d| d.id == json['list'] }
    if daily_item.nil?
      daily_item = DailyItem.new({
        'id' => json['list'],
        'items' => [json['item']]
      })
      day.add_item(daily_item)
    else
      daily_item.add_item(json['item'])
    end
    day.save!
    Day.add_day_for_item(json['item'], day.id)

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
    raise ListkError::NotFound, "List id '#{json['list']}' cannot be found" unless List.exist?(json['list'])

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
    day = Day.get(params['day'])
    raise ListError::NotFound, "Day '#{params['day']}' cannot be found" if day.nil?

    json = JSON.parse(request.body.read)
    raise ListError::BadRequest, "Request body must contain 'list' and 'item'." if !json.is_a?(Hash) || json['list'].to_s.empty? || json['item'].to_s.empty?
    raise ListError::NotFound, "List id '#{json['list']}' cannot be found" unless List.exist?(json['list'])

    daily_item = day.items.find { |d| d.id == json['list'] }
    if !daily_item.nil?
      daily_item.remove_item(json['item'])
      # Update the reference in the day
      day.items.map! { |d| d.id == json['list'] ? daily_item : d }
    end
    day.save!
    Day.remove_day_for_item(json['item'], day.id)

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
