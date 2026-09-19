require 'bundler/setup'
ENV['LISTS_BACKEND_E2E_TEST'] = 'true'
ENV['LISTS_BACKEND_PORT'] = '9191'

require 'json'
require 'fileutils'
require 'sinatra/cors'
require_relative './src/storage'

BACKEND_ROOT = File.expand_path(__dir__)

TypeStorage.clear_e2e_data

class Api < Sinatra::Base
  delete '/clear-e2e-data' do
    TypeStorage.clear_e2e_data
    status 204
  end

  post '/e2e/scenario' do
    json = get_json_payload(request)
    scenario_name = json['name']
    scenario_path = File.join(BACKEND_ROOT, 'scenarios', 'checkpoints', scenario_name)

    if !Dir.exist?(scenario_path)
      halt 404, { 'error' => "Scenario '#{scenario_name}' not found" }.to_json
    end

    TypeStorage.clear_e2e_data
    FileUtils.mkdir_p('e2e-data')
    FileUtils.cp_r(File.join(scenario_path, '.'), 'e2e-data')

    status 204
  end
end

Signal.trap('INT') do
  puts "Interrupt signal received. Cleaning up..."
  TypeStorage.clear_e2e_data
  Api.stop!
end

require_relative './api'