require_relative '../../exceptions'

def get_json_payload(request)
  begin
    json = JSON.parse(request.body.read)
  rescue JSON::ParserError
    raise ListError::BadRequest, "Request payload must be valid JSON"
  end
  json
end

def schema_endpoint_get(clazz, id)
  instance = clazz.get(id)
  if instance.nil?
    status 404
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

def schema_endpoint_list(clazz)
  instances = clazz.list.map { |it| it.to_schema_object }
  status 200
  body instances.to_json
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