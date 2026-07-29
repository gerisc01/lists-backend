require 'sinatra/base'
require_relative '../actions/occurrences'
require_relative '../actions/materialize_occurrence'

# Thin front doors over the recurrence materializer (design.md §2.5). Same shape as
# placements_api.rb: each delegates to a primitive and returns JSON. The read wraps
# the pure occurrences_for_week (ghosts for a visible week); the write is the
# "touch => real" seam that persists a ghost as a Placement (materialize_occurrence),
# after which the existing id-addressed /api/placements/* endpoints drive it.
class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Ghost occurrences for a week across a SET of collections (the recurring
  # counterpart of GET /api/placements). Query: ?collections=c1,c2&week_start=YYYY-MM-DD.
  # `as_of` defaults to today server-side. Untouched occurrences only — a materialized
  # one is represented by its real placement (GET /api/placements[/floating]) instead.
  get '/api/occurrences' do
    collection_ids = params['collections'].to_s.split(',').reject(&:empty?)
    if collection_ids.empty?
      raise ListError::BadRequest, "Query parameter 'collections' must be a non-empty comma-separated list of collection ids."
    end
    if params['week_start'].to_s.empty?
      raise ListError::BadRequest, "Query parameter 'week_start' is required (YYYY-MM-DD)."
    end
    status 200
    body occurrences_for_week(collection_ids, params['week_start']).to_json
  end

  # Materialize a ghost into a real Placement. Body: { "collection", "period_start"
  # (the ghost's due-week), "date"? }. With a date the occurrence is dated straight
  # onto that day; without one it lands floating in staging. Returns the persisted
  # placement (with its new id) so the client can then bind/complete/skip/defer it via
  # the existing /api/placements/:pid/* endpoints.
  post '/api/items/:id/occurrences' do
    json = JSON.parse(request.body.read)
    placement = materialize_occurrence(params['id'], json['collection'], json['period_start'], json['date'])
    status 200
    body placement.to_schema_object.to_json
  end

end
