require 'sinatra/base'
require_relative './src/lists'
require_relative './src/collection/collection_api'
require_relative './src/list/list_api'
require_relative './src/item/item_api'

class Api < Sinatra::Base

end

Api.run!