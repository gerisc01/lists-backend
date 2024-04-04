require 'sinatra/base'
require_relative '../actions/item_actions'

class Api < Sinatra::Base

  generate_schema_crud_methods 'actions', Action

  actions = action_methods.keys

  get '/api/actions/types' do
    status 200
    body actions.to_json
  end

  post '/api/actions/:action_id' do
    action = Action.get(params['action_id'])
    raise ListError::NotFound, "Action '#{params['action_id']}' not found." if action.nil?
    json = JSON.parse(request.body.read)
    action.steps.each do |step|
      step.process(json)
    end
    status 200
  end

end