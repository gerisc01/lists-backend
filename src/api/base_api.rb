module BaseApi

  def parse_body(body)
    begin
      return JSON.parse(body)
    rescue Exception => ex
      body "{\"message\": \"Input isn't json or is otherwise invalid\"}"
      puts "============ Error Message ===========" if ENV["LISTSPRGM_OUTPUT_ERRORS"] == "true"
      puts ex if ENV["LISTSPRGM_OUTPUT_ERRORS"] == "true"
      halt 400
    end
  end

  def bad_request(exception)
    output = {}
    output["message"] = exception.message
    body output.to_json
    puts "============ Error Message ===========" if ENV["LISTSPRGM_OUTPUT_ERRORS"] == "true"
    puts exception if ENV["LISTSPRGM_OUTPUT_ERRORS"] == "true"
    halt 400
  end

end