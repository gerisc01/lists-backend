ENV['LISTS_BACKEND_E2E_TEST'] = 'true'
ENV['LISTS_BACKEND_PORT'] = '9191'

require 'json'
require 'sinatra/cors'
require_relative './src/storage'

# If the e2e-data directory exists, delete it and its contents
TypeStorage.clear_e2e_data

# # Create the e2e-data directory
# Dir.mkdir('e2e-data')
#
# # Create a collections file
# File.open('e2e-data/collection.json', 'w') do |f|
#   f.write('{')
#   collection1 = {
#     'id' => '1',
#     'name' => 'First Collection',
#     'key' => 'first-collection',
#     'lists' => []
#   }
#   f.write('"1":' + collection1.to_json)
#   f.write(',')
#   collection2 = {
#     'id' => '2',
#     'name' => 'Second Collection',
#     'key' => 'second-collection',
#     'lists' => []
#   }
#   f.write('"2":' + collection2.to_json)
#   f.write('}')
# end

class Api < Sinatra::Base
  delete '/clear-e2e-data' do
    TypeStorage.clear_e2e_data
    status 204
  end
end

# When the user presses Ctrl+C, wipe the test data and exit the program
Signal.trap('INT') do
  puts "Interrupt signal received. Cleaning up..."
  TypeStorage.clear_e2e_data
  Api.stop!
end

require_relative './api'