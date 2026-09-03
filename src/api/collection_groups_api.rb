require 'sinatra/base'
require_relative '../type/collection_group'
require_relative 'helpers/list_api_framework'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Scoped LIST, then generated everything else — the same split collections make, and
  # for the same reason: a list read is the one place membership has to be enforced,
  # because it is the only read that answers "what is there".
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
