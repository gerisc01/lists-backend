require 'sinatra/base'
require 'sinatra/cors'
require_relative './src/api/helpers/list_api_framework'
require_relative './src/exceptions_api'
# Require all files in a directory ending with _api.rb
Dir[File.dirname(__FILE__) + '/src/api/*_api.rb'].each do |path|
  require_relative "./src/api/#{path.split('/')[-1]}"
end

class Api < Sinatra::Base
  register Sinatra::Cors

  # Setup
  set :show_exceptions => :after_handler

  before do
    content_type 'application/json'
  end

  set :allow_origin, '*'
  set :allow_methods, 'GET,POST,PUT,DELETE,OPTIONS'
  set :allow_headers, 'Content-Type, Accept'

  set :port, 9090
  set :bind, '0.0.0.0'
end

Api.run!
