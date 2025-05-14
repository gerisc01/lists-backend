require 'sinatra/base'
require_relative '../actions/item_actions'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # This needs to be defined before the schema crud methods are
  # generated, so that types can be a static endpoint instead of
  # the api thinking it is an action id.
  get '/api/actions/types' do
    status 200
    body action_methods.to_json
  end

  generate_schema_crud_methods 'actions', Action

  post '/api/actions/ad-hoc/:action_type' do
    action = Action.new
    action.name = 'Ad Hoc Action'
    action.steps = [ActionStep.new({
      'type' => params['action_type'],
      'fixed_params' => {}
    })]
    json = JSON.parse(request.body.read)
    action.steps.each do |step|
      step.process(json)
    end
    status 200
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
