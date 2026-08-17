require_relative '../type/placement'
require_relative '../actions/item_actions'
require_relative '../actions/auto_archive'

# Thin front doors over the placement primitives (assign_to_date / remove_from_date
# / set_placement_priority), which are also registry-registered for composition —
# same pattern as POST /api/items/:id/status. Each delegates to the primitive and
# returns the affected placement so the client can patch its cache.
class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Weekly-planning range read: placements in a collection across a date range,
  # grouped by date → { "YYYY-MM-DD": [<placement>, ...] }. Replaces the legacy
  # Day-based GET /api/dates/:collection/items?start&end.
  get '/api/collections/:id/placements' do
    if params['start'].to_s.empty? || params['end'].to_s.empty?
      raise ListError::BadRequest, "Query parameters must contain 'start' and 'end' dates."
    end
    raise ListError::BadRequest, "'start' date must be before 'end' date." if params['start'] > params['end']
    status 200
    body Placement.day_map_for_collection(params['id'], params['start'], params['end']).to_json
  end

  # Cross-collection weekly-planning range read (PR 8): placements across a SET of
  # collections in a date range → { "YYYY-MM-DD": [<placement>, ...] }. The mixed-grid
  # counterpart of the single-collection read above; a card bound from any staged
  # collection stays on the grid. Query: ?collections=c1,c2&start&end.
  #
  # Full placement objects (not bare item_ids): the grid needs the placement id to
  # write a resolution ("I did this") and the resolution to render a completed card
  # struck through in place. Resolved placements are deliberately NOT filtered out.
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

  # Cross-collection floating staging pile (PR 8): floating placements across a SET
  # of collections. Query: ?collections=c1,c2,c3. Full objects (binding is by
  # placement id), each carrying its source collection_id (for grouping) plus a
  # DERIVED `one_off` flag (item has no shelf/list home) so the client can bucket
  # board-born one-offs — reuses the canonical item_has_shelf_home? predicate.
  get '/api/placements/floating' do
    collection_ids = params['collections'].to_s.split(',').reject(&:empty?)
    if collection_ids.empty?
      raise ListError::BadRequest, "Query parameter 'collections' must be a non-empty comma-separated list of collection ids."
    end
    # The staging pile is week-scoped (docs/DECISIONS.md "Weekly planning is a weekly
    # PLAN"): ?week=<Monday YYYY-MM-DD> returns only placements staged for that week
    # (and still open). Omitting week falls back to the unfiltered pile (legacy).
    week = params['week'].to_s.empty? ? nil : params['week']
    placements = Placement.floating_for_collections(collection_ids, week)
    status 200
    body placements.map { |p| p.to_schema_object.merge('one_off' => !item_has_shelf_home?(p.item_id)) }.to_json
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
  # "YYYY-MM-DD", "staged_week"?: "YYYY-MM-DD" }. With a date → a dated placement
  # (assign to a day); without one → a floating placement that lands in staging for
  # `staged_week` (the current week, so the weekly-plan pile scopes to it).
  post '/api/items/:id/placements' do
    json = JSON.parse(request.body.read)
    placement =
      if json['date'].to_s.empty?
        create_floating_placement(params['id'], json['collection'], json['staged_week'])
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
  # "resolution", "assignee" } (other keys ignored). resolution is
  # "completed"|"skipped"|null (null reopens); resolved_at and resolved_by are
  # server-stamped. assignee is an account id (null clears) and is independent of
  # who is making the request — you assign other people, not just yourself.
  patch '/api/placements/:pid' do
    json = JSON.parse(request.body.read)
    placement = update_placement(params['pid'], json, current_account_id)
    status 200
    body placement.to_schema_object.to_json
  end

  # Defer a floating placement +1 week (design §4.4). Body: { "week_start":
  # "YYYY-MM-DD" } — the client's current-week start; the server computes the +1-week
  # not_before marker and stamps origin_date if absent.
  post '/api/placements/:pid/defer' do
    json = JSON.parse(request.body.read)
    placement = defer_placement(params['pid'], json['week_start'])
    status 200
    body placement.to_schema_object.to_json
  end

  # Re-float a dated placement back into staging: dated -> floating, the inverse of
  # /bind (design §4.4 "take it off the day"). Body: { "week_start": "YYYY-MM-DD" } —
  # the client's current-week start; the placement re-stages into that week. Clears any
  # resolution (a lapsed past-day card comes back open); preserves origin_date.
  post '/api/placements/:pid/unbind' do
    json = JSON.parse(request.body.read)
    placement = refloat_placement(params['pid'], json['week_start'])
    status 200
    body placement.to_schema_object.to_json
  end

  # Delete a placement outright (design §4.4 Delete). Id-addressed so it works on a
  # floating placement; removes the orphan board-born one-off item behind the shelf-home
  # guard. Distinct from the item-addressed DELETE /api/items/:id/placements (dated).
  delete '/api/placements/:pid' do
    placement = delete_placement(params['pid'])
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
