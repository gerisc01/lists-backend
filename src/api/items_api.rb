require_relative '../type/item'
require_relative '../actions/item_actions'
require_relative '../query/search'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Cross-collection item search. `?q=` takes a query in the language documented
  # in API.md ("Query language"), e.g. `energy = chill AND status != completed`.
  # Results come back grouped by collection.
  #
  # MUST stay above `generate_schema_crud_methods`: that generates
  # `GET /api/items/:id`, Sinatra matches routes in definition order, and a
  # generated route defined first would swallow this one as an item lookup with
  # id "query".
  get '/api/items/query' do
    query = params['q']
    raise ListError::BadRequest, "Missing required 'q' query parameter" if query.to_s.strip.empty?
    results = Query::Search.run(query)
    status 200
    body results.to_json
  end

  generate_schema_crud_methods 'items', Item

  # Server-authoritative lifecycle status change. Thin front door that delegates to
  # the set_status primitive (also registry-registered for composition) and returns
  # the updated item so the client can patch its cache. Body: { "status": "doing" }.
  post '/api/items/:id/status' do
    json = JSON.parse(request.body.read)
    item = set_status(params['id'], json['status'])
    status 200
    body item.to_schema_object.to_json
  end

end