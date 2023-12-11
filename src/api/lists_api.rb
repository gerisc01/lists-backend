require 'sinatra/base'
require_relative '../type/collection'
require_relative '../type/list'
require_relative '../type/item_generic'
require_relative '../type/item'
require_relative '../type/item_group'
require_relative '../type/tag'
require_relative '../type/template'
require_relative '../../src/api/list_api_framework'

require_relative '../actions/item_actions'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Api Methods
  generate_crud_methods 'collections', Collection
  generate_crud_methods 'lists', List
  generate_crud_methods 'items', Item
  generate_crud_methods 'itemGroups', ItemGroup
  generate_crud_methods 'tags', Tag
  generate_crud_methods 'templates', Template

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

  put '/api/itemGroups/:groupId/addItem/:itemId' do
    item_group = ItemGroup.get(params['groupId'])
    throw ListError::BadRequest, "Can't add a group item for an item that doesn't exist" if !Item.exist?(params['itemId'])
    item_group.add_group(params['itemId'])
    item_group.save!
    status 200
  end

  put '/api/itemGroups/:groupId/removeItem/:itemId' do
    item_group = ItemGroup.get(params['groupId'])
    throw ListError::BadRequest, "Can't remove an item if it is the only item remaining in the group" if item_group.group.length == 1
    item_group.remove_group(params['itemId'])
    item_group.save!
    status 200
  end

  put '/api/items/:itemId/moveItem' do
    json = JSON.parse(request.body.read)
    move_item(params['itemId'], json['fromList'], json['toList'])
    status 200
  end

  get '/api/collections/:collectionId/listItems' do
    collection_id = params['collectionId']
    collection = Collection.get(collection_id)
    items = []
    collection.lists.each do |list_id|
      list = List.get(list_id)
      item_ids = list.items
      if !item_ids.nil?
        item_ids.each do |item_id|
          it = ItemGeneric.get(item_id)
          if it.is_a?(Item)
            items.push(it.to_schema_object)
          elsif it.is_a?(ItemGroup)
            items.push(it.to_schema_object)
            it.group.each do |group_id|
              group_it = Item.get(group_id)
              items.push(group_it.to_schema_object)
            end
          end
        end
      end
    end
    status 200
    body items.to_json
  end

  get '/api/lists/:listId/items' do
    listId = params['listId']
    list = List.get(listId)
    item_ids = list.items
    items = []
    if !item_ids.nil?
      item_ids.each do |item_id|
        it = ItemGeneric.get(item_id)
        if it.is_a?(Item)
          items.push(it.to_schema_object)
        elsif it.is_a?(ItemGroup)
          items.push(it.to_schema_object)
          it.group.each do |group_id|
            group_it = Item.get(group_id)
            items.push(group_it.to_schema_object)
          end
        end
      end
    end
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