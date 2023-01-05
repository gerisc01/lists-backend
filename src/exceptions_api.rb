require 'sinatra/base'
require_relative './exceptions.rb'

class Api < Sinatra::Base

  error JSON::ParserError do
    error_body = {"error" => "Bad Request", "type" => "Invalid JSON", "message" => env['sinatra.error'].message}
    status 400
    body error_body.to_json
  end

  error ListError::Validation do
    error_body = {"error" => "Bad Request", "type" => "Validation Exception", "message" => env['sinatra.error'].message}
    status 400
    body error_body.to_json
  end

  error ListError::BadRequest do
    error_body = {"error" => "Bad Request", "type" => "Bad Request Error", "message" => env['sinatra.error'].message}
    status 400
    body error_body.to_json
  end

  error ListError::NotFound do
    error_body = {"error" => "Not Found", "message" => env['sinatra.error'].message}
    status 404
    body error_body.to_json
  end

  error do
    error_body = {"error" => "Internal Server Error", "message" => env['sinatra.error'].message}
    status 500
    body error_body.to_json
  end

end