require_relative './helpers/sinatra_crud_helpers'
require_relative '../type/item_group'

class Api < Sinatra::Base

  schema_type = ItemGroup

  ## Standard Crud Endpoints
  get "/api/items" do
    schema_endpoint_list(schema_type)
  end

  get "/api/items/:id" do
    schema_endpoint_get(schema_type, params['id'])
  end

  post "/api/items" do
    schema_endpoint_create(schema_type, request)
  end

  put "/api/items/:id" do
    schema_endpoint_update(schema_type, params['id'], request)
  end

  delete "/api/items/:id" do
    schema_endpoint_delete(schema_type, params['id'])
  end




end