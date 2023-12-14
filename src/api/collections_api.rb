require 'sinatra/base'
require_relative '../type/collection'
require_relative 'helpers/list_api_framework'
require_relative 'helpers/api_helpers'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  generate_schema_crud_methods 'collections', Collection

  get '/api/collections/:collectionId/listItems' do
    collection_id = params['collectionId']
    collection = Collection.get(collection_id)
    items = []
    collection.lists.each do |list_id|
      list = List.get(list_id)
      item_ids = list.items
      items += ApiHelpers.convert_item_ids_to_items(item_ids)
    end
    status 200
    body items.to_json
  end
end