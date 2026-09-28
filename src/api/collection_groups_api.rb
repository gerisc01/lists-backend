require 'sinatra/base'
require_relative '../type/collection_group'
require_relative 'helpers/list_api_framework'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  generate_schema_crud_methods 'collection-groups', CollectionGroup,
    scope: ->(records) { members_only(records) }

end
