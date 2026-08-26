#!/usr/bin/env ruby
# Drive the whole instance loop over HTTP in a few seconds.
#
# WHY THIS EXISTS: the loop it exercises is a multi-WEEK story — stage a game, play a
# session, come back next week, play again, finish it two months later, replay it in two
# years. None of that is testable by waiting, and none of it is time-dependent either:
# `staged_week` and every date are parameters. So the whole arc collapses into one run.
#
# It talks to the DISPOSABLE e2e backend (port 9191), which wipes its own data on boot, so
# it never touches data/. Start that first:
#
#   bundle exec ruby e2e_api.rb          # terminal 1
#   ruby scripts/instance_loop.rb        # terminal 2
#
# Unit tests already cover these rules in isolation. What this adds is the SERIALIZED
# shape a client actually receives — catalog_item_id and one_off are derived at the API
# boundary, and getting them wrong is what buries a playthrough in the One-offs pile.

require 'json'
require 'net/http'
require 'uri'

HOST = ENV['INSTANCE_LOOP_HOST'] || 'http://127.0.0.1:9191'

def call(method, path, body = nil)
  uri = URI("#{HOST}#{path}")
  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, put: Net::HTTP::Put }.fetch(method)
  request = klass.new(uri, 'Content-Type' => 'application/json')
  request.body = body.to_json unless body.nil?
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  unless response.code.to_i < 300
    abort "  #{method.to_s.upcase} #{path} -> #{response.code}\n  #{response.body}"
  end
  response.body.to_s.empty? ? nil : JSON.parse(response.body)
end

def action(type, body) = call(:post, "/api/actions/ad-hoc/#{type}", body)
def item(id) = call(:get, "/api/items/#{id}")

$failures = 0
def check(label, actual, expected)
  ok = actual == expected
  $failures += 1 unless ok
  puts "  #{ok ? "\e[32m✓\e[0m" : "\e[31m✗\e[0m"} #{label}#{ok ? '' : "  expected #{expected.inspect}, got #{actual.inspect}"}"
end

def step(title)
  puts "\n\e[1m#{title}\e[0m"
end

# ── Setup: a game that keeps a record, and a recipe that does not ──────────────────────
step 'Setup'
# Wipe first so the script is rerunnable without restarting the server.
begin
  uri = URI("#{HOST}/clear-e2e-data")
  Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(Net::HTTP::Delete.new(uri)) }
rescue StandardError
  abort "Could not reach the e2e backend at #{HOST}. Start it with: bundle exec ruby e2e_api.rb"
end
playthrough = call(:post, '/api/templates', {
  'key' => 'playthrough', 'display_name' => 'Playthrough',
  'fields' => [
    { 'key' => 'name', 'display_name' => 'Name', 'type' => 'String', 'required' => true },
    { 'key' => 'started', 'display_name' => 'Started', 'type' => 'SchemaType::Date' },
    { 'key' => 'finished', 'display_name' => 'Finished', 'type' => 'SchemaType::Date' },
  ],
})
games = call(:post, '/api/templates', {
  'key' => 'games', 'display_name' => 'Game',
  'fields' => [{ 'key' => 'name', 'display_name' => 'Name', 'type' => 'String', 'required' => true }],
  'attributes' => { 'instances' => { 'template' => playthrough['id'] } },
})
collection = call(:post, '/api/collections', { 'name' => 'Games' })
list = call(:post, '/api/lists', { 'name' => 'Playing', 'template' => games['id'] })
call(:put, "/api/collections/#{collection['id']}", { 'lists' => [list['id']] })
game = call(:post, "/api/lists/#{list['id']}/items", { 'name' => 'Kingdom Hearts' })
recipe = call(:post, '/api/items', { 'name' => 'Tacos' })
puts "  game #{game['id']} · collection #{collection['id']}"

W1, W2, W3 = '2026-08-17', '2026-08-24', '2028-01-03'

def stage(game_id, collection_id, week)
  call(:post, "/api/items/#{game_id}/placements", { 'collection' => collection_id, 'staged_week' => week })
end

def pile(collection_id, week)
  call(:get, "/api/placements/floating?collections=#{collection_id}&week=#{week}")
end

# ── Week 1: stage it ──────────────────────────────────────────────────────────────────
step 'Week 1 — stage it'
first = stage(game['id'], collection['id'], W1)
check('placement points at an instance, not the game', first['item_id'] != game['id'], true)
instance_id = first['item_id']

card = pile(collection['id'], W1).first
# THE CANARY. If either of these is wrong the card renders the instance's name and lands
# in the One-offs pile instead of Games — the whole substitution failing in the one place
# you would actually see it.
check('card resolves identity back to the game', card['catalog_item_id'], game['id'])
check('card is NOT flagged a one-off', card['one_off'], false)

check('staging does not start it', item(instance_id)['started'], nil)
check('staging does not move the game', item(game['id'])['status'], 'want-to')

# ── Week 1: play a session ────────────────────────────────────────────────────────────
step 'Week 1 — play a session'
action('bindPlacement', { 'placement_id' => first['id'], 'date' => '2026-08-18' })
action('updatePlacement', { 'placement_id' => first['id'], 'fields' => { 'resolution' => 'completed' } })
check('first completed session stamps started', item(instance_id)['started'], '2026-08-18')
check('the game is now doing', item(game['id'])['status'], 'doing')
check('one session does NOT finish the playthrough', item(instance_id)['finished'], nil)

# ── Week 2: the multi-week part, with no waiting ──────────────────────────────────────
step 'Week 2 — stage it again'
second = stage(game['id'], collection['id'], W2)
check('same instance, not a second one', second['item_id'], instance_id)
check('the game has exactly one playthrough', item(game['id'])['children'].length, 1)

# ── Finish it ─────────────────────────────────────────────────────────────────────────
step 'Finish it'
action('closeInstance', { 'instance_id' => instance_id, 'finished_date' => '2026-09-30' })
check('playthrough is finished', item(instance_id)['finished'], '2026-09-30')
check('the game is completed', item(game['id'])['status'], 'completed')

# ── Two years later: replay ───────────────────────────────────────────────────────────
step 'Two years later — replay'
third = stage(game['id'], collection['id'], W3)
check('a new playthrough mints', third['item_id'] != instance_id, true)
check('the game now has two', item(game['id'])['children'].length, 2)
check('replay does not move status until a session lands', item(game['id'])['status'], 'completed')
action('updatePlacement', { 'placement_id' => third['id'], 'fields' => { 'resolution' => 'completed' } })
check('now it is doing again', item(game['id'])['status'], 'doing')

# ── Backfill ──────────────────────────────────────────────────────────────────────────
step 'Backfill 2016'
action('createInstance', { 'item_id' => game['id'], 'fields' => { 'finished' => '2016-08-04' } })
check('the ledger has three', item(game['id'])['children'].length, 3)

# ── The control ───────────────────────────────────────────────────────────────────────
step 'Control — an item that does not keep a record'
plain = stage(recipe['id'], collection['id'], W1)
check('placement points at the recipe itself', plain['item_id'], recipe['id'])
check('no children were minted', item(recipe['id'])['children'], nil)

puts "\n#{$failures.zero? ? "\e[32mAll checks passed\e[0m" : "\e[31m#{$failures} FAILED\e[0m"}"
exit($failures.zero? ? 0 : 1)
