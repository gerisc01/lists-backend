module ApiHelpers
  
  def parse_json(input)
    begin
      json = JSON.parse(input)
    rescue JSON::ParseError => e
      error_body = {"error" => "Bad Request", "type" => "Invalid JSON", "message" => e.message}
      status 400
      body error_body.to_json
      halt
      raise
    end
    return json
  end

  def not_found(type, id)
    error_body = {"error" => "Not Found", "type" => "#{type}", "message" => "#{type} #{id} Not Found"}
    status 404
    body error_body.to_json
    halt
    raise "#{type} #{id} Not Found"
  end

end