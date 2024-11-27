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
    if params['since']
      since_body = ApiHelpers.convert_since_format(items, params['since'])
      if since_body['deleted_ids'].length > 0 || since_body['objects'].length > 0
        status 200
        body since_body.to_json
      else
        status 204
        body since_body.to_json
      end
    else
      status 200
      body items.to_json
    end
  end

  delete '/api/collections/:collectionId/actions/:actionId' do
    collection_id = params['collectionId']
    collection = Collection.get(collection_id)
    if collection.nil?
      status 404
    elsif collection.actions.nil? || !collection.actions.include?(params['actionId'])
      status 400
    else
      collection.lists.each do |list_id|
        list = List.get(list_id)
        if list.actions && list.actions.include?(params['actionId'])
          list.remove_action(params['actionId'])
          list.save!
        end
      end
      if collection.groups
        collection.groups.each do |group|
          if group.actions && group.actions.include?(params['actionId'])
            group.remove_action(params['actionId'])
          end
        end
      end
      collection.remove_action(params['actionId'])
      collection.save!
      status 204
    end
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

  delete '/api/collections/:collectionId/tags/:tagId' do
    collection_id = params['collectionId']
    collection = Collection.get(collection_id)
    if collection.nil?
      status 404
    elsif collection.tags.nil? || !collection.tags.include?(params['tagId'])
      status 400
    else
      collection.lists.each do |list_id|
        list = List.get(list_id)
        list.items.each do |item_id|
          item = ItemGeneric.get(item_id)
          # Handle regular items
          if item.is_a?(Item) && !item.tags.nil? && item.tags.include?(params['tagId'])
            item.remove_tag(params['tagId'])
            item.save!
          end
          # Handle group items
          if item.is_a?(ItemGroup)
            item.group.each do |group_item_id|
              group_item = ItemGeneric.get(group_item_id)
              if group_item.is_a?(Item) && group_item.tags && group_item.tags.include?(params['tagId'])
              group_item.remove_tag(params['tagId'])
              group_item.save!
              end
            end
          end
        end
      end
      collection.remove_tag(params['tagId'])
      collection.save!
      status 204
    end
  end
end