require 'sinatra/base'
require_relative '../actions/item_actions'

class Api < Sinatra::Base

  actions = ['moveItem', 'copyItem', 'removeItem']

  get '/api/actions' do
    status 200
    body actions.to_json
  end

  post '/api/actions/:action_name' do
    action = params['action_name']
    raise ListError::BadRequest, "Action '#{action}' is not a valid action." if !actions.include?(action)
    json = JSON.parse(request.body.read)
    if action == 'moveItem'
      move_item(json['item_id'], json['from_list'], json['to_list'])
      status 200
    elsif action == 'copyItem'
      copy_item(json['item_id'], json['to_list'])
      status 200
    elsif action == 'removeItem'
      remove_item(json['item_id'], json['from_list'], json['item_index'])
      status 200
    end
  end

end