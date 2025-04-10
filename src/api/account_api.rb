require 'sinatra/base'
require_relative '../type/account'

class Api < Sinatra::Base

  post '/api/accounts' do
    json = JSON.parse(request.body.read)
    raise ListError::BadRequest, "Missing 'name' field." if json['name'].nil?
    new_account = Account.new({'name' => json['name']})
    new_account.validate
    new_account.save!

    status 201
    body new_account.to_schema_object.to_json
  end

  get '/api/accounts/:account_id' do
    # Authenticate the user because the /accounts endpoint isn't protected by default
    # copy/paste from api.rb protected block
    account_header = request.env['HTTP_ACCOUNT_ID']&.split(' ')&.last
    account = Account.get(account_header)
    if account.nil? || account.id != account_header
      halt 401, {'error' => 'Unauthorized', 'message' => 'Invalid API key' }.to_json
    end
    # end copy/paste
    account = Account.get(params['account_id'])
    raise ListError::NotFound, "Account '#{params['account_id']}' not found." if account.nil?
    status 200
    body account.to_schema_object.to_json
  end

  put '/api/accounts/:account_id' do
    # Authenticate the user because the /accounts endpoint isn't protected by default
    # copy/paste from api.rb protected block
    account_header = request.env['HTTP_ACCOUNT_ID']&.split(' ')&.last
    account = Account.get(account_header)
    if account.nil? || account.id != account_header
      halt 401, {'error' => 'Unauthorized', 'message' => 'Invalid API key' }.to_json
    end
    # end copy/paste
    account = Account.get(params['account_id'])
    raise ListError::NotFound, "Account '#{params['account_id']}' not found." if account.nil?
    account.merge!(JSON.parse(request.body.read))
    account.validate
    account.save!
    status 200
    body account.to_schema_object.to_json
  end

  delete '/api/accounts/:account_id' do
    # Authenticate the user because the /accounts endpoint isn't protected by default
    # copy/paste from api.rb protected block
    account_header = request.env['HTTP_ACCOUNT_ID']&.split(' ')&.last
    account = Account.get(account_header)
    if account.nil? || account.id != account_header
      halt 401, {'error' => 'Unauthorized', 'message' => 'Invalid API key' }.to_json
    end
    # end copy/paste
    account = Account.get(params['account_id'])
    raise ListError::NotFound, "Account '#{params['account_id']}' not found." if account.nil?
    account.delete! unless account.nil?
    status 204
  end

end
