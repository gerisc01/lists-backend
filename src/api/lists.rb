require 'sinatra/base'
require_relative './base_api'
require_relative '../list'

class Api < Sinatra::Base

  helpers BaseApi

  get '/api/lists' do
    List.list.to_json
  end
  
  post '/api/lists' do
    input = request.body.read
    json_input = parse_body(input)
    list = createAndValidate(json_input["name"])
    created_list = List.create(list)
    status 201
    body created_list.to_json
  end

  def createAndValidate(name)
    begin
      List.new(name)
    rescue Exception => ex
      bad_request(ex)
    end
  end

  def validate(list)
    begin
      list.validate
    rescue Exception => ex
      bad_request(ex)
    end
  end

end