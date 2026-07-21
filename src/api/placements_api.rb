require_relative '../type/placement'
require_relative '../actions/item_actions'

# Thin front doors over the placement primitives (assign_to_date / remove_from_date
# / set_placement_priority), which are also registry-registered for composition —
# same pattern as POST /api/items/:id/status. Each delegates to the primitive and
# returns the affected placement so the client can patch its cache.
class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Weekly-planning range read: items placed in a collection across a date range,
  # grouped by date → { "YYYY-MM-DD": ["item_id", ...] }. Replaces the legacy
  # Day-based GET /api/dates/:collection/items?start&end.
  get '/api/collections/:id/placements' do
    if params['start'].to_s.empty? || params['end'].to_s.empty?
      raise ListError::BadRequest, "Query parameters must contain 'start' and 'end' dates."
    end
    raise ListError::BadRequest, "'start' date must be before 'end' date." if params['start'] > params['end']
    status 200
    body Placement.day_map_for_collection(params['id'], params['start'], params['end']).to_json
  end

  # Placements for one item (reverse lookup: "what days is this item on").
  get '/api/items/:id/placements' do
    placements = Placement.for_item(params['id'])
    status 200
    body placements.map(&:to_schema_object).to_json
  end

  # Assign an item to a day. Body: { "collection": "<id>", "date": "YYYY-MM-DD" }.
  post '/api/items/:id/placements' do
    json = JSON.parse(request.body.read)
    placement = assign_to_date(params['id'], json['date'], json['collection'])
    status 200
    body placement.to_schema_object.to_json
  end

  # Remove an item from a day. Body: { "collection": "<id>", "date": "YYYY-MM-DD" }.
  delete '/api/items/:id/placements' do
    json = JSON.parse(request.body.read)
    placement = remove_from_date(params['id'], json['date'], json['collection'])
    status 200
    body(placement.nil? ? '{}' : placement.to_schema_object.to_json)
  end

  # Flag/unflag a dated placement as a priority (per-date cap enforced in the
  # primitive). Body: { "collection": "<id>", "date": "YYYY-MM-DD", "priority": true }.
  post '/api/items/:id/placements/priority' do
    json = JSON.parse(request.body.read)
    placement = set_placement_priority(params['id'], json['date'], json['collection'], json['priority'])
    status 200
    body placement.to_schema_object.to_json
  end

end
