require 'sinatra/base'
require_relative './item'
require_relative '../helpers/api_helpers.rb'
require_relative '../helpers/exceptions.rb'

class Api < Sinatra::Base

  set :show_exceptions => :after_handler
  
  before do
    content_type 'application/json'
  end

  get '/api/items' do
    items = Item.list.map { |item| item.to_object }
    status 200
    body items.to_json
  end

  post '/api/items' do
    json = JSON.parse(request.body.read)
    item = Item.new(json)
    item.validate
    item.save!
    status 201
    body item.json.to_json
  end

  put '/api/items/:id' do
    id = params['id']
    item = Item.get(id)
    raise NotFoundError, "Item (#{id}) Not Found" if item.nil?
    json = JSON.parse(request.body.read)
    item.merge!(json)
    item.validate
    item.save!
    status 200
    body item.json.to_json
  end

  delete '/api/items/:id' do
    id = params['id']
    item = Item.get(id)
    item.delete! unless item.nil?
    status 204
  end

  get '/api/lists/:listId/items' do
    listId = params['listId']
    list = List.get(listId)
    items = list.items.map { |itemId| Item.get(itemId).json }
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

  error JSON::ParserError do
    error_body = {"error" => "Bad Request", "type" => "Invalid JSON", "message" => env['sinatra.error'].message}
    status 400
    body error_body.to_json
  end

  error BadRequestError do
    error_body = {"error" => "Bad Request", "type" => "Bad Request Error", "message" => env['sinatra.error'].message}
    status 400
    body error_body.to_json
  end

  error ValidationError do
    error_body = {"error" => "Bad Request", "type" => "Validation Exception", "message" => env['sinatra.error'].message}
    status 400
    body error_body.to_json
  end

  error NotFoundError do
    error_body = {"error" => "Not Found", "message" => env['sinatra.error'].message}
    status 404
    body error_body.to_json
  end

  error do
    require 'pry'; binding.pry
    error_body = {"error" => "Internal Server Error", "message" => env['sinatra.error'].message}
    status 500
    body error_body.to_json
  end

end