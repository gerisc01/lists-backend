require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/placement'
require_relative '../../src/type/day'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/type/list'

# The thin POST /api/reconcile front door. The primitive itself is covered by
# test/actions/reconcile_test.rb; this spec only proves the endpoint delegates, passes
# an injected as_of_date through, and returns the {released,lapsed,archived,pruned}
# summary (weekly-plan reframe — docs/DECISIONS.md).
class ReconcileApiTest < MinitestWrapper
  include Rack::Test::Methods

  AS_OF = '2026-07-27'
  PAST  = '2026-07-20'   # strictly before AS_OF — a day that is over

  def app
    Api.new
  end

  def setup
    @collection = Collection.new({'id' => 'c1', 'name' => 'Collection'})
    @collection.save!
    Day.toggle_cache_source(:test)
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def new_item(id, scheduling: nil)
    attrs = {'id' => id, 'name' => id}
    attrs['scheduling'] = {'type' => scheduling} if scheduling
    Item.new(attrs).tap(&:save!)
    id
  end

  def dated(item_id, date, overrides = {})
    Placement.new({
      'item_id' => item_id, 'collection_id' => 'c1',
      'date' => date, 'floating' => false, 'origin_date' => date,
    }.merge(overrides)).tap(&:validate).tap(&:save!)
  end

  def reconcile_request(as_of_date: AS_OF)
    post('/api/reconcile',
         { 'as_of_date' => as_of_date }.to_json,
         { 'Content-Type' => 'application/json' })
  end

  def test_endpoint_lapses_a_past_one_off_task
    new_item('t')
    p = dated('t', PAST)

    reconcile_request
    assert_equal 200, last_response.status
    result = JSON.parse(last_response.body)
    assert_equal [p.id], result['lapsed']

    lapsed = Placement.get(p.id)
    refute_nil lapsed                     # retained, not deleted
    assert_equal 'lapsed', lapsed.resolution
  end

  def test_endpoint_archives_a_past_one_off_event
    new_item('e', scheduling: 'event')
    dated('e', PAST)

    reconcile_request
    assert_equal 200, last_response.status
    result = JSON.parse(last_response.body)
    assert_equal ['e'], result['archived']
    assert_equal 'completed', Item.get('e').json['status']
  end

  def test_endpoint_is_idempotent
    new_item('t')
    dated('t', PAST)

    reconcile_request
    reconcile_request
    result = JSON.parse(last_response.body)
    assert_empty result['lapsed']
    assert_equal 1, Placement.for_item('t').size   # lapsed row retained, not duplicated
  end

  def test_endpoint_defaults_as_of_to_today_with_empty_body
    # No body → as_of_date defaults to today; a future-dated task is not yet past, so
    # nothing lapses. Proves the default path parses without a JSON error.
    new_item('t')
    future = (Date.today + 7).iso8601
    dated('t', future)

    post('/api/reconcile')
    assert_equal 200, last_response.status
    result = JSON.parse(last_response.body)
    assert_empty result['lapsed']
    refute_nil Placement.for_item('t').first.date
  end

end
