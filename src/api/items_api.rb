require_relative '../type/item'
require_relative '../actions/item_actions'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

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