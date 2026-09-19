require 'bundler/setup'
require_relative './src/base_api'

port = ENV['LISTS_BACKEND_PORT'] || 9090

puts "Starting API server via root api.rb on port #{port}..."

BaseApi.start(port: port)
Api.run!
