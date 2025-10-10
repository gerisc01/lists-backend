require 'sinatra/base'
require 'sinatra/cors'
require_relative './src/api/helpers/list_api_framework'
require_relative './src/exceptions_api'
# Require all files in a directory ending with _api.rb
Dir[File.dirname(__FILE__) + '/src/api/*_api.rb'].each do |path|
  require_relative "./src/api/#{path.split('/')[-1]}"
end
require_relative './src/type/template_types/dropdown'
require_relative './src/type/template_types/week_days'
require_relative './src/type/template_types/integer_patch'
require_relative './src/type/account'

class Api < Sinatra::Base
  puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ LOADING MAIN API ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  register Sinatra::Cors

  # Setup
  set :show_exceptions => :after_handler

  set :allow_origin, '*'
  set :allow_methods, 'GET,POST,PUT,DELETE,OPTIONS'
  set :allow_headers, 'Content-Type, Accept, ACCOUNT_ID'

  helpers do
    def protected!
      # HTTP_ACCOUNT_ID correlates to a ACCOUNT_ID: <Token> header
      account_header = request.env['HTTP_ACCOUNT_ID']&.split(' ')&.last
      account = Account.get(account_header)
      if !account.nil? && account.id == account_header
        return true
      end
      halt 401, {'error' => 'Unauthorized', 'message' => 'Invalid API key' }.to_json
    end
  end

  before do
    if request.request_method != 'OPTIONS'
      protected! unless request.path_info == '/api/accounts'
    end
    content_type 'application/json'
  end

  if ENV['LISTS_BACKEND_PORT']
    set :port, ENV['LISTS_BACKEND_PORT']
  else
    set :port, 9090
  end
  set :bind, '0.0.0.0'

end

Api.run!
