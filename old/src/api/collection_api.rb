require 'sinatra/base'
require_relative '../type/collection'
require_relative './helpers.rb'
require_relative '../exceptions.rb'

class Api < Sinatra::Base

  set :show_exceptions => :after_handler
  
  before do
    content_type 'application/json'
  end

  get '/api/collections' do
    collections = Collection.list.map { |collection| collection.to_object }
    status 200
    body collections.to_json
  end
  
  post '/api/collections' do
    json = JSON.parse(request.body.read)
    collection = Collection.new(json)
    collection.validate
    collection.save!
    status 201
    body collection.json.to_json
  end

  put '/api/collections/:id' do
    id = params['id']
    collection = Collection.get(id)
    raise NotFoundError, "Collection (#{id}) Not Found" if collection.nil?
    json = JSON.parse(request.body.read)
    collection.merge!(json)
    collection.validate
    collection.save!
    status 200
    body collection.json.to_json
  end

  delete '/api/collections/:id' do
    id = params['id']
    collection = Collection.get(id)
    collection.delete! unless collection.nil?
    status 204
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