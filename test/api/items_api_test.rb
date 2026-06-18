require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/status'

class ItemsApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item.save!
  end

  def post_status(id, status)
    post("/api/items/#{id}/status", { 'status' => status }.to_json,
         { "Content-Type" => "application/json" })
  end

  def reloaded
    Item.get('1').json
  end

  # New items are born `want-to`.
  def test_birth_status_default
    assert_equal 'want-to', reloaded['status']
    assert_nil reloaded['transitions']
  end

  def test_start_sets_doing_and_stamps_one_transition
    post_status('1', 'doing')
    assert_equal 200, last_response.status

    item = reloaded
    assert_equal 'doing', item['status']
    assert_equal 1, item['transitions'].length
    t = item['transitions'].first
    assert_equal 'want-to', t['from']
    assert_equal 'doing', t['to']
    refute_nil t['at']
  end

  def test_sequence_accumulates_ordered_history
    post_status('1', 'doing')
    post_status('1', 'completed')

    item = reloaded
    assert_equal 'completed', item['status']
    froms = item['transitions'].map { |t| t['from'] }
    tos   = item['transitions'].map { |t| t['to'] }
    assert_equal %w[want-to doing], froms
    assert_equal %w[doing completed], tos
  end

  def test_on_hold_and_retired
    post_status('1', 'on-hold')
    assert_equal 'on-hold', reloaded['status']
    post_status('1', 'retired')
    assert_equal 'retired', reloaded['status']
  end

  # The endpoint returns the updated item so the client can patch its cache.
  def test_response_returns_updated_item
    post_status('1', 'doing')
    body = JSON.parse(last_response.body)
    assert_equal 'doing', body['status']
    assert_equal '1', body['id']
  end

  # Client-supplied timestamp is ignored — the server owns `at`.
  def test_client_cannot_forge_timestamp
    post("/api/items/1/status",
         { 'status' => 'doing', 'at' => '1999-01-01T00:00:00Z' }.to_json,
         { "Content-Type" => "application/json" })
    assert_equal 200, last_response.status
    refute_equal '1999-01-01T00:00:00Z', reloaded['transitions'].first['at']
  end

  def test_unknown_status_is_rejected
    post_status('1', 'bogus')
    assert_equal 400, last_response.status
    assert_equal 'want-to', reloaded['status']
  end

  def test_missing_item_is_not_found
    post_status('NOPE', 'doing')
    assert_equal 404, last_response.status
  end

  # Status validation type guards the enum.
  def test_status_type_match
    assert Status.type_match?('doing')
    refute Status.type_match?('done')   # no stored `done` value
    refute Status.type_match?('bogus')
  end

  # `done` is a derived predicate over the two terminal statuses.
  def test_done_predicate
    assert Status.done?('completed')
    assert Status.done?('retired')
    refute Status.done?('doing')
    refute Status.done?('on-hold')
  end

  # Malformed transition entries fail validation (Transition type guards the shape).
  def test_transition_type_match
    assert Transition.type_match?({ 'from' => 'want-to', 'to' => 'doing', 'at' => 't' })
    assert Transition.type_match?({ 'from' => nil, 'to' => 'doing', 'at' => 't' })
    refute Transition.type_match?({ 'to' => 'bogus', 'at' => 't' })
    refute Transition.type_match?({ 'from' => 'want-to', 'to' => 'doing' }) # no `at`
  end
end
