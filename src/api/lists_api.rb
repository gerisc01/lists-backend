require 'sinatra/base'
require_relative '../type/collection'
require_relative '../type/list'
require_relative '../type/item'
require_relative '../../src/api/list_api_framework'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Api Methods
  generate_crud_methods 'collections', Collection
  generate_crud_methods 'lists', List
  generate_crud_methods 'items', Item

  put '/api/lists/:listId/addItem/:itemId' do
    item = Item.get(params['itemId'])
    list = List.get(params['listId'])
    list.add_item(item)
    list.save!
    status 200
  end

  put '/api/lists/:listId/removeItem/:itemId' do
    item = Item.get(params['itemId'])
    list = List.get(params['listId'])
    list.remove_item(item)
    list.save!
    status 200
  end

  put '/api/items/:itemId/moveItem' do
    json = JSON.parse(request.body.read)
    fromListId = json['fromList']
    toListId = json['toList']
    throw BadRequestError, "Need a listId for both fromList and toList in payload" if fromListId.to_s.empty? || toListId.to_s.empty?
    
    itemId = params['itemId']
    item = Item.get(itemId)
    fromList = List.get(fromListId)
    fromList.remove_item(item)
    toList = List.get(toListId)
    toList.add_item(item)
    fromList.save!
    toList.save!
    status 200
  end

  get '/api/lists/:listId/items' do
    listId = params['listId']
    list = List.get(listId)
    item_ids = list.items
    items = item_ids.nil? ? [] : item_ids.map { |itemId| Item.get(itemId).json }
    status 200
    body items.to_json
  end

  post '/api/lists/:listId/items' do
    json = JSON.parse(request.body.read)
    listId = params['listId']
    item = Item.new(json)
    list = List.get(listId)
    list.add_item(item)
    list.save!
    status 201
    body item.json.to_json
  end

end