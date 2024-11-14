require 'sinatra/base'
require_relative '../../exceptions'

module Sinatra

  module ListApiUtils

    def get_json_payload(request)
      begin
        json = JSON.parse(request.body.read)
      rescue JSON::ParserError
        raise ListError::BadRequest, "Request payload must be valid JSON"
      end
      json
    end

    def schema_endpoint_get(clazz, id, since)
      instance = clazz.get(id)
      if instance.nil?
        status 404
      elsif !since.nil? && instance.json['updated_at'] < since
        status 204
      else
        status 200
        body instance.to_schema_object.to_json
      end
    end

    def schema_endpoint_create(clazz, request)
      instance = clazz.new(get_json_payload(request))
      instance.validate
      instance.save!
      status 201
      body instance.to_schema_object.to_json
    end

    def schema_endpoint_list(clazz, since)
      since = Time.now.utc.iso8601 if since.to_s.downcase == 'now'
      instances = clazz.list({since: since, include_deleted: true})
                       .map { |it| it.to_schema_object }
      if !since.nil? && !instances.nil? && instances.empty?
        updated_info = {
          'deleted_ids' => [],
          'objects' => []
        }
        status 204
        body updated_info.to_json
      elsif !since.nil?
        updated_info = {
          'deleted_ids' => instances.select { |it| it['deleted'] }.map { |it| it['id'] },
          'objects' => instances.reject { |it| it['deleted'] }
        }
        status 200
        body updated_info.to_json
      else
        status 200
        body instances.reject { |it| it['deleted'] }.to_json
      end
    end

    def schema_endpoint_update(clazz, id, request)
      instance = clazz.get(id)
      raise ListError::NotFound, "#{clazz.to_s} (#{id}) Not Found" if instance.nil?
      instance.merge!(get_json_payload(request))
      instance.validate
      instance.save!
      status 200
      body instance.to_schema_object.to_json
    end

    def schema_endpoint_delete(clazz, id)
      instance = clazz.get(id)
      instance.delete! unless instance.nil?
      status 204
    end

  end


  module ListApiFramework

    def generate_schema_endpoint(type, endpoint, clazz)
      case type
      when :list
        get "/api/#{endpoint}" do
          schema_endpoint_list(clazz, params['since'])
        end
      when :get
        get "/api/#{endpoint}/:id" do
          schema_endpoint_get(clazz, params['id'], params['since'])
        end
      when :create
        post "/api/#{endpoint}" do
          schema_endpoint_create(clazz, request)
        end
      when :update
        put "/api/#{endpoint}/:id" do
          schema_endpoint_update(clazz, params['id'], request)
        end
      when :delete
        delete "/api/#{endpoint}/:id" do
          schema_endpoint_delete(clazz, params['id'])
        end
      else
        raise "Error generating endpoint; Unknown endpoint type '#{type}'."
      end
    end

    def generate_schema_crud_methods(endpoint, clazz)
      generate_schema_endpoint(:list, endpoint, clazz)
      generate_schema_endpoint(:get, endpoint, clazz)
      generate_schema_endpoint(:create, endpoint, clazz)
      generate_schema_endpoint(:update, endpoint, clazz)
      generate_schema_endpoint(:delete, endpoint, clazz)
    end

    def self.registered(app)
      app.helpers Sinatra::ListApiUtils
    end

  end
end