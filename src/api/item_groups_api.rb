require 'sinatra/base'
require_relative '../type/item_group'
require_relative '../../src/api/helpers/list_api_framework'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Member -> group lookup: the groups claiming any of ?ids=a,b,c. The planner needs it
  # because a card must say which bigger thing its item is part of, and the item alone
  # can't answer that — a member carries no back-pointer. Derived on read rather than
  # stamped onto the placement, so renaming a group or moving a member out is reflected
  # immediately instead of leaving a stale label on the board.
  #
  # Declared ABOVE the generated CRUD on purpose: Sinatra matches in definition order, and
  # the generated GET /api/itemGroups/:id would otherwise swallow this path as an id.
  get '/api/itemGroups/forMembers' do
    ids = params['ids'].to_s.split(',').reject(&:empty?)
    status 200
    body ItemGroup.for_members(ids).map { |g| g.to_schema_object }.to_json
  end

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