require 'sinatra/base'
require 'sinatra/cors'
require_relative './src/api/list_api_framework'
require_relative './src/exceptions_api'
require_relative './src/api/lists_api'

class Api < Sinatra::Base
  register Sinatra::Cors

  # Setup
  set :show_exceptions => :after_handler

  before do
    content_type 'application/json'
  end

  set :allow_origin, '*'
  set :allow_methods, 'GET,POST,PUT,DELETE'
  set :allow_headers, 'Content-Type, Accept'

  set :port, 9090
  set :bind, '0.0.0.0'
end

Api.run!
