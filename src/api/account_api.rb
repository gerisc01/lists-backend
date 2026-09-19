require 'sinatra/base'
require_relative '../type/account'
require_relative 'helpers/list_api_framework'

class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  post '/api/accounts' do
    json = get_json_payload(request)
    raise ListError::BadRequest, "Missing 'name' field." if json['name'].nil?
    new_account = Account.new({'name' => json['name']})
    new_account.validate
    new_account.save!

    status 201
    body new_account.to_schema_object.to_json
  end

  get '/api/accounts/:accountId' do
    # copy/paste from Api's protected! helper (also already run by the before hook)
    account_header = request.env['HTTP_ACCOUNT_ID']&.split(' ')&.last
    account = Account.get(account_header)
    if account.nil? || account.id != account_header
      halt 401, {'error' => 'Unauthorized', 'message' => 'Invalid API key' }.to_json
    end
    # end copy/paste
    account = Account.get(params['accountId'])
    raise ListError::NotFound, "Account '#{params['accountId']}' not found." if account.nil?
    status 200
    body account.to_schema_object.to_json
  end

  put '/api/accounts/:accountId' do
    # copy/paste from Api's protected! helper (also already run by the before hook)
    account_header = request.env['HTTP_ACCOUNT_ID']&.split(' ')&.last
    account = Account.get(account_header)
    if account.nil? || account.id != account_header
      halt 401, {'error' => 'Unauthorized', 'message' => 'Invalid API key' }.to_json
    end
    # end copy/paste
    account = Account.get(params['accountId'])
    raise ListError::NotFound, "Account '#{params['accountId']}' not found." if account.nil?
    account.merge!(get_json_payload(request))
    account.validate
    account.save!
    status 200
    body account.to_schema_object.to_json
  end

  delete '/api/accounts/:accountId' do
    # copy/paste from Api's protected! helper (also already run by the before hook)
    account_header = request.env['HTTP_ACCOUNT_ID']&.split(' ')&.last
    account = Account.get(account_header)
    if account.nil? || account.id != account_header
      halt 401, {'error' => 'Unauthorized', 'message' => 'Invalid API key' }.to_json
    end
    # end copy/paste
    account = Account.get(params['accountId'])
    raise ListError::NotFound, "Account '#{params['accountId']}' not found." if account.nil?
    account.delete! if !account.nil?
    status 204
  end

end
