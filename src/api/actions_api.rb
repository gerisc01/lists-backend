require 'sinatra/base'
require_relative '../actions/item_actions'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  # Above the generated routes, or GET /api/actions/:actionId would match "types".
  get '/api/actions/types' do
    status 200
    body action_methods.to_json
  end

  generate_schema_crud_methods 'actions', Action

  helpers do
    # Always overwritten from the request, so a body or stored fixed_params can't set the author.
    def with_actor(json)
      return json.merge('actor_id' => current_account_id)
    end
  end

  post '/api/actions/ad-hoc/:action_type' do
    action = Action.new
    action.name = 'Ad Hoc Action'
    action.steps = [ActionStep.new({
      'type' => params['action_type'],
      'fixed_params' => {}
    })]
    json = with_actor(get_json_payload(request))
    action.steps.each do |step|
      step.process(json)
    end
    status 200
  end

  post '/api/actions/:action_id' do
    action = Action.get(params['action_id'])
    raise ListError::NotFound, "Action '#{params['action_id']}' not found." if action.nil?
    json = with_actor(get_json_payload(request))
    action.steps.each do |step|
      step.process(json)
    end
    status 200
  end

end
