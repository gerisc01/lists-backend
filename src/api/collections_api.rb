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

  delete '/api/collections/:collectionId/templates/:templateId' do
    collection_id = params['collectionId']
    collection = Collection.get(collection_id)
    if collection.nil?
      status 404
    elsif collection.templates.nil? || !collection.templates.include?(params['templateId'])
      status 400
    else
      items = []
      collection.lists.each do |list_id|
        list = List.get(list_id)
        if list.template == params['templateId']
          list.template = nil
          list.items.each do |item_id|
            item = ItemGeneric.get(item_id)
            item.remove_template(params['templateId'])
            item.save!
          end
          list.save!
        end
      end
      collection.remove_template(params['templateId'])
      collection.save!
      status 204
    end
  end
end