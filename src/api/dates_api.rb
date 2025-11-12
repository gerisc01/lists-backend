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

  generate_schema_crud_methods 'dates', Day

end
