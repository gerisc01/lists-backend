require 'bundler/setup'
require_relative './src/base_api'

# --- Main Application Entry Point ---

# Load configuration for port, defaulting to the value from the original api.rb
# or a common default if ENV['LISTS_BACKEND_PORT'] is not set.
port = ENV['LISTS_BACKEND_PORT'] || 9090

puts "Starting API server via root api.rb on port #{port}..."

# This call is blocking, as this is the primary entry point for running the API.
BaseApi.start(port: port)
Api.run!
