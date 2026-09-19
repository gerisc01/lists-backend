require 'sinatra/base'
require_relative '../type/item_group'
require_relative '../../src/api/helpers/list_api_framework'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # ?ids=a,b,c. Above the generated routes, or GET /api/itemGroups/:itemGroupId would match it.
  get '/api/itemGroups/forMembers' do
    ids = params['ids'].to_s.split(',').reject(&:empty?)
    status 200
    body ItemGroup.for_members(ids).map { |g| g.to_schema_object }.to_json
  end

  generate_schema_crud_methods 'itemGroups', ItemGroup

  put '/api/itemGroups/:groupId/addItem/:itemId' do
    item_group = ItemGroup.get(params['groupId'])
    raise ListError::BadRequest, "Can't add a group item for an item that doesn't exist" if !Item.exist?(params['itemId'])
    item_group.add_group(params['itemId'])
    item_group.save!
    status 200
  end

  put '/api/itemGroups/:groupId/removeItem/:itemId' do
    item_group = ItemGroup.get(params['groupId'])
    raise ListError::BadRequest, "Can't remove an item if it is the only item remaining in the group" if item_group.group.length == 1
    item_group.remove_group(params['itemId'])
    item_group.save!
    status 200
  end

end