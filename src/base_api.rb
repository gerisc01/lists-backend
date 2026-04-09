require 'sinatra/base'
require 'sinatra/cors'
require_relative './api/helpers/list_api_framework'
require_relative './exceptions_api'
# Require all files in a directory ending with _api.rb
Dir[File.dirname(__FILE__) + '/api/*_api.rb'].each do |path|
  require_relative "./api/#{File.basename(path)}"
end
require_relative './type/template_types/dropdown'
require_relative './type/template_types/week_days'
require_relative './type/template_types/integer_patch'
require_relative './type/template_types/recurring_date'
require_relative './type/account'

# This class defines the core API application logic and routes.
class BaseApi < Sinatra::Base
  puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ LOADING BASE API DEFINITION ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
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
    # Allow OPTIONS requests for CORS preflight without authentication
    # Authenticate other requests unless it's a specific path (like accounts creation)
    if request.request_method != 'OPTIONS'
      protected! unless request.path_info == '/api/accounts'
    end
    content_type 'application/json'
  end

  # Class method to start the server. This is the reusable part.
  def self.start(port: 9090, bind: '0.0.0.0')
    Api.set :port, port
    Api.set :bind, bind

    # Check if the todo template already exists, if not create it
    unless Template.exist?('todo')
      todo_template = Template.new
      todo_template.id = 'todo'
      todo_template.key = 'todo'
      todo_template.display_name = 'To Do'
      todo_template.fields = [
        { :key => 'todo-date', :required => false, :type => SchemaType::Date, :display_name => 'Due Date' },
        { :key => 'completed', :required => false, :type => SchemaType::Boolean, :display_name => 'Completed' },
      ]
      todo_template.save!
    end

    # Mirror the storage environment in the cache so they always stay in sync.
    if TypeStorage.is_e2e_test
      Day.toggle_cache_source(:e2e)
    elsif TypeStorage.scenario_var_set
      Day.toggle_cache_source(:scenario)
    end

    Day.clear_cache
    Day.build_full_day_index

    puts "Base API definition loaded. Server configured for port #{port}."
  end
end

class Api < Sinatra::Base
  register Sinatra::Cors

  set :allow_origin, '*'
  set :allow_methods, 'GET,POST,PUT,DELETE,OPTIONS'
  set :allow_headers, 'Content-Type, Accept, ACCOUNT_ID'

  helpers do
    def protected!
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
end
