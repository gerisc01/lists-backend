require 'sinatra/base'
require_relative '../type/list'
require_relative '../type/item_generic'
require_relative 'helpers/list_api_framework'
require_relative 'helpers/api_helpers'

require_relative '../actions/item_actions'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Api Methods
  generate_schema_crud_methods 'lists', List

  put '/api/lists/:listId/addItem/:itemId' do
    item = ItemGeneric.get(params['itemId'])
    list = List.get(params['listId'])
    list.add_item(item)
    list.save!
    status 200
  end

  put '/api/lists/:listId/removeItem/:itemId' do
    item = ItemGeneric.get(params['itemId'])
    list = List.get(params['listId'])
    list.remove_item(item)
    list.save!
    status 200
  end

  get '/api/lists/:listId/items' do
    listId = params['listId']
    list = List.get(listId)
    item_ids = list.items
    items = ApiHelpers.convert_item_ids_to_items(item_ids)
    status 200
    body items.to_json
  end

  post '/api/lists/:listId/items' do
    json = JSON.parse(request.body.read)
    listId = params['listId']
    item = ItemGeneric.from_schema_object(json)
    list = List.get(listId)
    list.add_item(item)
    list.save!
    status 201
    body item.json.to_json
  end

end