require 'sinatra/base'
require_relative '../actions/occurrences'
require_relative '../actions/materialize_occurrence'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # ?collections=c1,c2&week_start=YYYY-MM-DD. Untouched occurrences only.
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

  # Body: { "collection", "period_start", "date"?, "staged_week"? }.
  post '/api/items/:itemId/occurrences' do
    json = get_json_payload(request)
    placement = materialize_occurrence(params['itemId'], json['collection'], json['period_start'],
                                       json['date'], json['staged_week'])
    status 200
    body placement.to_schema_object.to_json
  end

end
