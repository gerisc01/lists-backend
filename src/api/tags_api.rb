require 'sinatra/base'
require_relative '../type/tag'
require_relative '../../src/api/helpers/list_api_framework'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  generate_schema_crud_methods 'tags', Tag
end