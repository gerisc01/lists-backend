require 'sinatra/base'
require_relative './src/api/lists'

class Api < Sinatra::Base

  ENV["LISTSPRGM_OUTPUT_ERRORS"] = "true"

end

Api.run!