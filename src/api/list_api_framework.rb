require 'sinatra/base'
require_relative '../exceptions'

module Sinatra

  module ListApiUtils

    def get_json_payload(request)
      begin
        json = JSON.parse(request.body.read)
      rescue JSON::ParserError
        raise ListError::BadRequest, "Request payload must be valid JSON"
      end
      return json
    end

  end

  module ListApiFramework

    def generate_crud_methods(endpoint, clazz)
      post "/api/#{endpoint}" do
        instance = clazz.new(get_json_payload(request))
        instance.validate
        instance.save!
        status 201
        body instance.json.to_json
      end
    
      # get (retrieve)
      get "/api/#{endpoint}/:id" do
        id = params['id']
        instance = clazz.get(id)
        if instance.nil?
          status 404
        else
          status 200
          body instance.to_object.to_json
        end
      end
    
      # list (retrieve)
      get "/api/#{endpoint}" do
        instances = clazz.list.map { |it| it.to_object }
        status 200
        body instances.to_json
      end
    
      # update
      put "/api/#{endpoint}/:id" do
        id = params['id']
        instance = clazz.get(id)
        raise ListError::NotFound, "#{clazz.to_s} (#{id}) Not Found" if instance.nil?
        instance.merge!(get_json_payload(request))
        instance.validate
        instance.save!
        status 200
        body instance.json.to_json
      end
    
      # delete
      delete "/api/#{endpoint}/:id" do
        id = params['id']
        instance = clazz.get(id)
        instance.delete! unless instance.nil?
        status 204
      end
    end

    def self.registered(app)
      app.helpers Sinatra::ListApiUtils
    end

  end
end