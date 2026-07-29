require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/type/placement'

# PR 13 — the recurrence endpoints: GET /api/occurrences (ghosts for a week) and
# POST /api/items/:id/occurrences (materialize a ghost into a real placement).
class OccurrencesApiTest < MinitestWrapper
  include Rack::Test::Methods

  W2 = '2026-07-20'   # a due-week
  FRI_W3 = '2026-07-31'
  JSON_HEADERS = { 'Content-Type' => 'application/json' }.freeze

  def app
    Api.new
  end

  def setup
    Collection.new({ 'id' => 'c1', 'name' => 'Collection' }).save!
    Item.new({
      'id' => 'trash', 'name' => 'Trash',
      'scheduling' => {
        'type' => 'task',
        'recurrence' => {
          'cadence' => 'weekly', 'interval' => 2, 'mode' => 'absolute',
          'anchor' => { 'kind' => 'floating' }, 'collection_id' => 'c1',
          'active' => true, 'start_date' => W2,
        },
      },
    }).save!
    Day.toggle_cache_source(:test)
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def materialize(body)
    post('/api/items/trash/occurrences', body.to_json, JSON_HEADERS)
  end

  # ── GET /api/occurrences ─────────────────────────────────────────────────────

  def test_get_returns_the_weeks_ghosts
    get("/api/occurrences?collections=c1&week_start=#{W2}")
    assert_equal 200, last_response.status
    ghosts = JSON.parse(last_response.body)
    assert_equal 1, ghosts.length
    assert_equal true, ghosts.first['ghost']
    assert_equal 'trash', ghosts.first['rule_item_id']
    assert_equal W2, ghosts.first['period_start']
  end

  def test_get_requires_collections_and_week_start
    get("/api/occurrences?week_start=#{W2}")
    assert_equal 400, last_response.status
    get('/api/occurrences?collections=c1')
    assert_equal 400, last_response.status
  end

  # ── POST /api/items/:id/occurrences ──────────────────────────────────────────

  def test_post_materializes_a_dated_placement
    materialize({ 'collection' => 'c1', 'period_start' => W2, 'date' => FRI_W3 })
    assert_equal 200, last_response.status
    placement = JSON.parse(last_response.body)
    assert_equal FRI_W3, placement['date']
    assert_equal W2, placement['origin_date']
    refute_nil placement['id']
  end

  def test_post_without_a_date_materializes_a_floating_placement
    materialize({ 'collection' => 'c1', 'period_start' => W2 })
    placement = JSON.parse(last_response.body)
    assert_nil placement['date']
    assert_equal true, placement['floating']
    assert_equal W2, placement['origin_date']
  end

  def test_post_is_idempotent_and_removes_the_ghost
    materialize({ 'collection' => 'c1', 'period_start' => W2, 'date' => FRI_W3 })
    first_id = JSON.parse(last_response.body)['id']
    materialize({ 'collection' => 'c1', 'period_start' => W2, 'date' => FRI_W3 })
    assert_equal first_id, JSON.parse(last_response.body)['id']
    assert_equal 1, Placement.for_item('trash').length

    get("/api/occurrences?collections=c1&week_start=#{W2}")
    assert_empty JSON.parse(last_response.body), 'materialized occurrence no longer ghosts'
  end

end
