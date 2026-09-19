require 'sinatra/base'
require_relative '../type/collection_group'
require_relative 'helpers/list_api_framework'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Only the list read filters by membership; the rest are generated.
  get '/api/collection-groups' do
    groups = CollectionGroup.list.reject { |g| g.json['deleted'] }
    groups = members_only(groups)
    status 200
    body groups.map(&:to_schema_object).to_json
  end

  generate_schema_endpoint(:get, 'collection-groups', CollectionGroup)
  generate_schema_endpoint(:create, 'collection-groups', CollectionGroup)
  generate_schema_endpoint(:update, 'collection-groups', CollectionGroup)
  generate_schema_endpoint(:delete, 'collection-groups', CollectionGroup)

end
