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

  put '/api/lists/:id' do
    instance = List.get(id)
    original_template_id = instance.template
    raise ListError::NotFound, "List (#{id}) Not Found" if instance.nil?
    instance.merge!(get_json_payload(request))
    instance.validate
    instance.save!
    if !original_template_id.nil? && instance.template.nil?
      instance.items.each do |item_id|
        item = ItemGeneric.get(item_id)
        item.remove_template(original_template_id)
        item.save!
      end
    end
    status 200
    body instance.to_schema_object.to_json
  end

  put '/api/lists/:listId/addItem/:itemId' do
    item = ItemGeneric.get(params['itemId'])
    list = List.get(params['listId'])
    list.add_item_with_template_ref(item)
    list.save!
    status 200
  end

  put '/api/lists/:listId/removeItem/:itemId' do
    item = ItemGeneric.get(params['itemId'])
    list = List.get(params['listId'])
    list.remove_item_with_template_ref(item)
    list.save!
    status 200
  end

  get '/api/lists/:listId/items' do
    list_id = params['listId']
    list = List.get(list_id)
    item_ids = list.items
    items = ApiHelpers.convert_item_ids_to_items(item_ids)
    if params['since']
      since_body = ApiHelpers.convert_since_format(items, params['since'])
      if since_body['deleted_ids'].length > 0 || since_body['objects'].length > 0
        status 200
        body since_body.to_json
      else
        status 204
        body since_body.to_json
      end
    else
      status 200
      body items.to_json
    end
  end

  post '/api/lists/:listId/items' do
    json = JSON.parse(request.body.read)
    list_id = params['listId']
    if !json['id'].nil?
      item = ItemGeneric.get(json['id'])
      raise ListError::BadRequest, "Item with id '#{json['id']}' already exists" if !item.nil?
    end
    item = ItemGeneric.from_schema_object(json)
    list = List.get(list_id)
    list.add_item_with_template_ref(item)
    list.save!
    status 201
    body item.json.to_json
  end

  put '/api/lists/:listId/items/:itemId' do
    if !params['listId'] || !params['itemId']
      raise ListError::BadRequest, "listId and itemId required"
    end
    list = List.get(params['listId'])
    raise ListError::NotFound, "List (#{id}) Not Found" if list.nil?
    item = ItemGeneric.get(params['itemId'])
    raise ListError::NotFound, "Item (#{id}) Not Found" if item.nil?
    item.merge!(get_json_payload(request))
    item.add_template(list.template) if list.template && (item.templates.nil? || !item.templates.has?(list.template))
    item.validate
    item.save!
    status 200
    body item.to_schema_object.to_json
  end

  post '/api/lists/:listId/actions' do
    json = JSON.parse(request.body.read)
    list_id = params['listId']
    list = List.get(list_id)
    action = Action.new(json)
    action.save!
    list.add_action(action)
    list.save!
    status 201
    body list.json.to_json
  end

end