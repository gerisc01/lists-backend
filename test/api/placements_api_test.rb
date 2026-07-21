require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/placement'
require_relative '../../src/type/day'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'

class PlacementsApiTest < MinitestWrapper
  include Rack::Test::Methods

  DATE = '2026-07-22'

  def app
    Api.new
  end

  def setup
    @collection = Collection.new({'id' => 'c1', 'name' => 'Collection'})
    @items = %w[i1 i2 i3 i4].map { |id| Item.new({'id' => id, 'name' => id}) }
    [@collection, *@items].each(&:save!)
    Day.toggle_cache_source(:test)
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def assign(item_id, date: DATE, collection: 'c1')
    post("/api/items/#{item_id}/placements",
         { 'collection' => collection, 'date' => date }.to_json,
         { 'Content-Type' => 'application/json' })
  end

  def set_priority(item_id, priority, date: DATE, collection: 'c1')
    post("/api/items/#{item_id}/placements/priority",
         { 'collection' => collection, 'date' => date, 'priority' => priority }.to_json,
         { 'Content-Type' => 'application/json' })
  end

  # ── Assign / read / remove ──────────────────────────────────────────────────

  def test_assign_creates_dated_placement
    assign('i1')
    assert_equal 200, last_response.status
    p = JSON.parse(last_response.body)
    assert_equal 'i1', p['item_id']
    assert_equal DATE, p['date']
    assert_equal false, p['floating']
    assert_equal 1, Placement.for_item('i1').size
  end

  def test_assign_is_idempotent
    assign('i1')
    first = JSON.parse(last_response.body)['id']
    assign('i1')
    second = JSON.parse(last_response.body)['id']
    assert_equal first, second
    assert_equal 1, Placement.for_date(DATE).size
  end

  def test_assign_unknown_item_is_not_found
    assign('does-not-exist')
    assert_equal 404, last_response.status
  end

  def test_get_placements_for_item
    assign('i1')
    assign('i1', date: '2026-07-23')
    get('/api/items/i1/placements')
    assert_equal 200, last_response.status
    assert_equal 2, JSON.parse(last_response.body).size
  end

  def test_remove_deletes_placement
    assign('i1')
    delete('/api/items/i1/placements',
           { 'collection' => 'c1', 'date' => DATE }.to_json,
           { 'Content-Type' => 'application/json' })
    assert_equal 200, last_response.status
    assert_equal 0, Placement.for_item('i1').size
  end

  # ── Priority + per-date cap ─────────────────────────────────────────────────

  def test_priority_flag_sets_and_reports
    assign('i1')
    set_priority('i1', true)
    assert_equal 200, last_response.status
    assert_equal true, JSON.parse(last_response.body)['priority']
  end

  def test_priority_requires_existing_placement
    set_priority('i1', true)
    assert_equal 404, last_response.status
  end

  def test_priority_cap_per_date
    @items.each { |i| assign(i.id) }
    %w[i1 i2 i3].each do |id|
      set_priority(id, true)
      assert_equal 200, last_response.status
    end
    # The 4th priority on the same date is rejected.
    set_priority('i4', true)
    assert_equal 400, last_response.status
    assert_equal 3, Placement.for_date(DATE).count { |p| p.priority == true }
  end

  def test_cap_does_not_block_unflagging_then_reflagging
    @items.first(3).each { |i| assign(i.id); set_priority(i.id, true) }
    set_priority('i1', false)
    assert_equal 200, last_response.status
    assign('i4')
    set_priority('i4', true)
    assert_equal 200, last_response.status
  end

  # ── Derived day-view matches the legacy Day read (the 5a proof) ──────────────

  def test_day_view_matches_legacy_day_grouping
    # Legacy Day: two items in one collection on DATE.
    day = Day.new({'id' => DATE, 'items' => [{'id' => 'c1', 'items' => ['i1', 'i2']}]})
    day.save!
    legacy = {}
    day.items.each { |di| legacy[di.id] = di.items }

    # Same assignments as placements.
    assign('i1')
    assign('i2')
    derived = Placement.day_view(DATE)['items'].transform_values(&:sort)

    assert_equal legacy.transform_values(&:sort), derived
  end

end
