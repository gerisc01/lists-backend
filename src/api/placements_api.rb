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

  # Floating placements for a collection's staging pile (dayless). Full objects,
  # since binding one to a day is addressed by its placement id.
  get '/api/collections/:id/placements/floating' do
    placements = Placement.floating_for_collection(params['id'])
    status 200
    body placements.map(&:to_schema_object).to_json
  end

  # Create a placement for an item. Body: { "collection": "<id>", "date"?:
  # "YYYY-MM-DD" }. With a date → a dated placement (assign to a day); without one
  # → a floating placement that lands in staging (bind it to a day later).
  post '/api/items/:id/placements' do
    json = JSON.parse(request.body.read)
    placement =
      if json['date'].to_s.empty?
        create_floating_placement(params['id'], json['collection'])
      else
        assign_to_date(params['id'], json['date'], json['collection'])
      end
    status 200
    body placement.to_schema_object.to_json
  end

  # Bind a placement to a day: floating -> dated. Body: { "date": "YYYY-MM-DD" }.
  post '/api/placements/:pid/bind' do
    json = JSON.parse(request.body.read)
    placement = bind_placement(params['pid'], json['date'])
    status 200
    body placement.to_schema_object.to_json
  end

  # Edit a placement's per-instance fields. Body: any of { "note", "time_cost",
  # "completed" } (other keys ignored). completed_at is server-stamped.
  patch '/api/placements/:pid' do
    json = JSON.parse(request.body.read)
    placement = update_placement(params['pid'], json)
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
