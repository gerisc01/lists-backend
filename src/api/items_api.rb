require_relative '../type/item'
require_relative '../actions/item_actions'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  generate_schema_crud_methods 'items', Item

  put '/api/items/:itemId/moveItem' do
    json = JSON.parse(request.body.read)
    move_item(params['itemId'], json['fromList'], json['toList'])
    status 200
  end

end