require 'sinatra/base'
require 'sinatra/cors'
require_relative './src/lists'
require_relative './src/api/collection_api'
require_relative './src/api/list_api'
require_relative './src/api/item_api'

class Api < Sinatra::Base
  register Sinatra::Cors

  set :allow_origin, '*'
  set :allow_methods, 'GET,POST,PUT,DELETE'
  set :allow_headers, 'Content-Type, Accept'

  set :port, 9090
  set :bind, '0.0.0.0'
end

Api.run!
