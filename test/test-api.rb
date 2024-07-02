require 'sinatra/base'
require_relative '../src/api/helpers/list_api_framework'
require_relative '../src/exceptions_api'
# Require all files in a directory ending with _api.rb
Dir[File.dirname(__FILE__) + '/../src/api/*_api.rb'].each do |path|
  require_relative "../src/api/#{path.split('/')[-1]}"
end

# A trimmed down version of the api.rb file for testing purposes
class Api < Sinatra::Base
  set :show_exceptions => :after_handler

  before do
    content_type 'application/json'
  end

end