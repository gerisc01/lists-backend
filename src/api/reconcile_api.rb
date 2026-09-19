require 'date'
require_relative '../actions/reconcile'

# Called by bin/reconcile_loop.sh. The optional `as_of_date` body field lets tests run it for another day.
class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  post '/api/reconcile' do
    json = get_json_payload(request, optional: true)
    result = reconcile(as_of_date: json['as_of_date'] || Date.today.iso8601)
    status 200
    body result.to_json
  end

end
