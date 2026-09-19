require_relative '../type/item'
require_relative '../actions/item_actions'
require_relative '../query/search'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # ?q= uses the query language in API.md. Above the generated routes, or GET /api/items/:itemId
  # would match "query".
  get '/api/items/query' do
    query = params['q']
    raise ListError::BadRequest, "Missing required 'q' query parameter" if query.to_s.strip.empty?
    results = Query::Search.run(query)
    status 200
    body results.to_json
  end

  generate_schema_crud_methods 'items', Item

  # Body: { "status": "doing" }.
  post '/api/items/:itemId/status' do
    json = get_json_payload(request)
    item = set_status(params['itemId'], json['status'], current_account_id)
    status 200
    body item.to_schema_object.to_json
  end

end