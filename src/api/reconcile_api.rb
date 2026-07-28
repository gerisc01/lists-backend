require 'date'
require_relative '../actions/reconcile'

# PR 9b — the front door for the idempotent reconcile primitive (PR 9a). This is
# the "dumb, safe trigger" surface: an external hourly loop (bin/reconcile_loop.sh)
# and the weekly-planner-load call both POST here. reconcile is global + structurally
# idempotent, so this endpoint needs no locking/dedupe — re-running is a no-op.
#
# Not registry-registered (unlike set_status): reconcile takes no positional item
# params and isn't composed into other flows — it's a standalone sweep. Body is
# optional; `as_of_date` is accepted so tests/backfills can drive "a week later"
# deterministically, and defaults to today for the real loop.
class Api < Sinatra::Base
  register Sinatra::ListApiFramework

  post '/api/reconcile' do
    json = JSON.parse(request.body.read) rescue {}
    result = reconcile(as_of_date: json['as_of_date'] || Date.today.iso8601)
    status 200
    body result.to_json
  end

end
