require 'sinatra/base'
require_relative '../type/item_group'
require_relative '../../src/api/helpers/list_api_framework'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  generate_schema_crud_methods 'itemGroups', ItemGroup

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

end