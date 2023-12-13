require_relative '../type/item'

class Api < Sinatra::Base

  schema_type = Item

  ## Standard Crud Endpoints
  generate_schema_endpoint(:list, 'items', schema_type)
  generate_schema_endpoint(:get, 'items', schema_type)
  generate_schema_endpoint(:create, 'items', schema_type)
  generate_schema_endpoint(:update, 'items', schema_type)
  generate_schema_endpoint(:delete, 'items', schema_type)

end