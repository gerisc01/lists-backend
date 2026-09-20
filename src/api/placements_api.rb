require_relative '../type/placement'
require_relative '../actions/item_actions'
require_relative '../actions/auto_archive'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # ?start&end → { "YYYY-MM-DD": [placement, ...] }.
  get '/api/collections/:collectionId/placements' do
    if params['start'].to_s.empty? || params['end'].to_s.empty?
      raise ListError::BadRequest, "Query parameters must contain 'start' and 'end' dates."
    end
    raise ListError::BadRequest, "'start' date must be before 'end' date." if params['start'] > params['end']
    status 200
    body Placement.day_map_for_collection(params['collectionId'], params['start'], params['end']).to_json
  end

  # ?collections=c1,c2&start&end → { "YYYY-MM-DD": [placement, ...] }, resolved ones included.
  get '/api/placements' do
    collection_ids = params['collections'].to_s.split(',').reject(&:empty?)
    if collection_ids.empty?
      raise ListError::BadRequest, "Query parameter 'collections' must be a non-empty comma-separated list of collection ids."
    end
    if params['start'].to_s.empty? || params['end'].to_s.empty?
      raise ListError::BadRequest, "Query parameters must contain 'start' and 'end' dates."
    end
    raise ListError::BadRequest, "'start' date must be before 'end' date." if params['start'] > params['end']
    status 200
    body Placement.day_map_for_collections(collection_ids, params['start'], params['end']).to_json
  end

  # ?collections=c1,c2 → { catalog_item_id => account_id }. Not date-scoped, since a collection
  # screen shows items regardless of week.
  get '/api/placements/current' do
    collection_ids = params['collections'].to_s.split(',').reject(&:empty?)
    if collection_ids.empty?
      raise ListError::BadRequest, "Query parameter 'collections' must be a non-empty comma-separated list of collection ids."
    end
    status 200
    body Placement.current_assignees_for_collections(collection_ids).to_json
  end

  # ?collections=c1,c2&week=YYYY-MM-DD. Adds `one_off` (the item has no list home).
  get '/api/placements/floating' do
    collection_ids = params['collections'].to_s.split(',').reject(&:empty?)
    if collection_ids.empty?
      raise ListError::BadRequest, "Query parameter 'collections' must be a non-empty comma-separated list of collection ids."
    end
    # No week returns every week's pile.
    week = params['week'].to_s.empty? ? nil : params['week']
    placements = Placement.floating_for_collections(collection_ids, week)
    status 200
    # Asks about the catalog item; an instance itself is never in a list.
    body placements.map { |p| p.to_client_object.merge('one_off' => !item_has_shelf_home?(p.catalog_item_id)) }.to_json
  end

  get '/api/items/:itemId/placements' do
    placements = Placement.for_item(params['itemId'])
    status 200
    body placements.map(&:to_client_object).to_json
  end

  get '/api/collections/:collectionId/placements/floating' do
    placements = Placement.floating_for_collection(params['collectionId'])
    status 200
    body placements.map(&:to_schema_object).to_json
  end

  # Body: { "collection", "date"?, "staged_week"? }. Without a date it's floating.
  post '/api/items/:itemId/placements' do
    json = get_json_payload(request)
    placement =
      if json['date'].to_s.empty?
        create_floating_placement(params['itemId'], json['collection'], json['staged_week'], current_account_id)
      else
        assign_to_date(params['itemId'], json['date'], json['collection'], current_account_id)
      end
    status 200
    body placement.to_schema_object.to_json
  end

  # Body: { "date": "YYYY-MM-DD" }.
  post '/api/placements/:placementId/bind' do
    json = get_json_payload(request)
    placement = bind_placement(params['placementId'], json['date'])
    status 200
    body placement.to_schema_object.to_json
  end

  # Body: any of { "note", "time_cost", "resolution", "assignee" }; other keys are ignored.
  patch '/api/placements/:placementId' do
    json = get_json_payload(request)
    placement = update_placement(params['placementId'], json, current_account_id)
    status 200
    body placement.to_schema_object.to_json
  end

  # Body: { "week_start": "YYYY-MM-DD" }, the client's current week.
  post '/api/placements/:placementId/defer' do
    json = get_json_payload(request)
    placement = defer_placement(params['placementId'], json['week_start'])
    status 200
    body placement.to_schema_object.to_json
  end

  # Body: { "week_start": "YYYY-MM-DD" }, the client's current week.
  post '/api/placements/:placementId/unbind' do
    json = get_json_payload(request)
    placement = refloat_placement(params['placementId'], json['week_start'])
    status 200
    body placement.to_schema_object.to_json
  end

  delete '/api/placements/:placementId' do
    placement = delete_placement(params['placementId'])
    status 200
    body placement.to_schema_object.to_json
  end

  # Body: { "collection", "date" }. Dated placements only.
  delete '/api/items/:itemId/placements' do
    json = get_json_payload(request)
    placement = remove_from_date(params['itemId'], json['date'], json['collection'])
    status 200
    body(placement.nil? ? '{}' : placement.to_schema_object.to_json)
  end

  # Body: { "collection", "date", "priority": true }.
  post '/api/items/:itemId/placements/priority' do
    json = get_json_payload(request)
    placement = set_placement_priority(params['itemId'], json['date'], json['collection'], json['priority'])
    status 200
    body placement.to_schema_object.to_json
  end

end
