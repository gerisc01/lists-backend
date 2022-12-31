require 'sinatra/base'
require_relative '../type/list'
require_relative './helpers.rb'
require_relative '../exceptions.rb'

class Api < Sinatra::Base

  set :show_exceptions => :after_handler
  
  before do
    content_type 'application/json'
  end

  get '/api/lists' do
    lists = List.list.map { |list| list.to_object }
    status 200
    body lists.to_json
  end
  
  post '/api/lists' do
    json = JSON.parse(request.body.read)
    list = List.new(json)
    list.validate
    list.save!
    status 201
    body list.json.to_json
  end

  put '/api/lists/:id' do
    id = params['id']
    list = List.get(id)
    raise NotFoundError, "List (#{id}) Not Found" if list.nil?
    json = JSON.parse(request.body.read)
    list.merge!(json)
    list.validate
    list.save!
    status 200
    body list.json.to_json
  end

  delete '/api/lists/:id' do
    id = params['id']
    list = List.get(id)
    list.delete! unless list.nil?
    status 204
  end

  put '/api/lists/:listId/addItem/:itemId' do
    itemId = params['itemId']
    listId = params['listId']
    item = Item.get(itemId)
    list = List.get(listId)
    list.add_item(item)
    list.save!
    status 200
  end

  put '/api/lists/:listId/removeItem/:itemId' do
    itemId = params['itemId']
    listId = params['listId']
    item = Item.get(itemId)
    list = List.get(listId)
    list.remove_item(item)
    list.save!
    status 200
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