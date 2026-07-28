require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/placement'
require_relative '../../src/type/day'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/type/list'

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

  # ── Range read for weekly planning ──────────────────────────────────────────

  def test_collection_range_read_groups_by_date
    assign('i1')                       # DATE
    assign('i2')                       # DATE
    assign('i3', date: '2026-07-24')
    get("/api/collections/c1/placements?start=2026-07-20&end=2026-07-26")
    assert_equal 200, last_response.status
    map = JSON.parse(last_response.body)
    assert_equal %w[i1 i2].sort, map[DATE].sort
    assert_equal %w[i3], map['2026-07-24']
  end

  def test_collection_range_read_excludes_other_collections
    other = Collection.new({'id' => 'c2', 'name' => 'Other'}); other.save!
    assign('i1')                        # c1
    assign('i2', collection: 'c2')      # c2
    get("/api/collections/c1/placements?start=2026-07-20&end=2026-07-26")
    map = JSON.parse(last_response.body)
    assert_equal %w[i1], map[DATE]
  end

  def test_collection_range_read_requires_start_and_end
    get("/api/collections/c1/placements")
    assert_equal 400, last_response.status
  end

  # ── Floating placements + bind (5c) ─────────────────────────────────────────

  def stage(item_id, collection: 'c1')
    post("/api/items/#{item_id}/placements",
         { 'collection' => collection }.to_json,
         { 'Content-Type' => 'application/json' })
  end

  def test_create_floating_placement
    stage('i1')
    assert_equal 200, last_response.status
    p = JSON.parse(last_response.body)
    assert_equal 'i1', p['item_id']
    assert_nil p['date']
    assert_equal true, p['floating']
    refute_nil p['id']
  end

  def test_create_floating_is_deduped_per_item_and_collection
    stage('i1')
    first = JSON.parse(last_response.body)['id']
    stage('i1')
    second = JSON.parse(last_response.body)['id']
    assert_equal first, second
    assert_equal 1, Placement.floating_for_collection('c1').size
  end

  def test_floating_read_returns_only_this_collections_floating
    stage('i1')
    assign('i2')                              # dated, excluded
    other = Collection.new({'id' => 'c2', 'name' => 'Other'}); other.save!
    stage('i3', collection: 'c2')             # floating in c2, excluded
    get('/api/collections/c1/placements/floating')
    assert_equal 200, last_response.status
    floating = JSON.parse(last_response.body)
    assert_equal 1, floating.size
    assert_equal 'i1', floating.first['item_id']
  end

  def test_bind_flips_floating_to_dated
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    post("/api/placements/#{pid}/bind",
         { 'date' => DATE }.to_json, { 'Content-Type' => 'application/json' })
    assert_equal 200, last_response.status
    bound = JSON.parse(last_response.body)
    assert_equal DATE, bound['date']
    assert_equal false, bound['floating']
    assert_equal 0, Placement.floating_for_collection('c1').size
    assert_equal 1, Placement.for_date(DATE).size
  end

  def test_bind_requires_a_date
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    post("/api/placements/#{pid}/bind", {}.to_json, { 'Content-Type' => 'application/json' })
    assert_equal 400, last_response.status
  end

  def test_bind_unknown_placement_is_not_found
    post('/api/placements/nope/bind',
         { 'date' => DATE }.to_json, { 'Content-Type' => 'application/json' })
    assert_equal 404, last_response.status
  end

  def test_update_placement_note_and_time_cost
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}",
          { 'note' => 'do it well', 'time_cost' => 45 }.to_json,
          { 'Content-Type' => 'application/json' })
    assert_equal 200, last_response.status
    updated = JSON.parse(last_response.body)
    assert_equal 'do it well', updated['note']
    assert_equal 45, updated['time_cost']
  end

  def test_update_placement_resolution_stamps_resolved_at
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}",
          { 'resolution' => 'completed' }.to_json, { 'Content-Type' => 'application/json' })
    done = JSON.parse(last_response.body)
    assert_equal 'completed', done['resolution']
    refute_nil done['resolved_at']

    patch("/api/placements/#{pid}",
          { 'resolution' => nil }.to_json, { 'Content-Type' => 'application/json' })
    reopened = JSON.parse(last_response.body)
    assert_nil reopened['resolution']
    assert_nil reopened['resolved_at']
  end

  def test_update_placement_accepts_skipped_resolution
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}",
          { 'resolution' => 'skipped' }.to_json, { 'Content-Type' => 'application/json' })
    assert_equal 200, last_response.status
    assert_equal 'skipped', JSON.parse(last_response.body)['resolution']
  end

  def test_update_placement_rejects_unknown_resolution
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}",
          { 'resolution' => 'bogus' }.to_json, { 'Content-Type' => 'application/json' })
    assert_equal 400, last_response.status
  end

  def test_update_placement_ignores_unknown_fields
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}",
          { 'floating' => false, 'date' => DATE, 'note' => 'kept' }.to_json,
          { 'Content-Type' => 'application/json' })
    updated = JSON.parse(last_response.body)
    assert_equal 'kept', updated['note']
    assert_nil updated['date']              # not writable here
    assert_equal true, updated['floating']  # not writable here
  end

  # ── Auto-archive one-offs when all placements resolve (PR 6 + PR 9) ──────────

  def resolve(pid, value = 'completed')
    patch("/api/placements/#{pid}",
          { 'resolution' => value }.to_json, { 'Content-Type' => 'application/json' })
  end

  def status_of(item_id)
    Item.get(item_id).json['status']
  end

  def test_board_born_item_archives_when_its_only_placement_completes
    assign('i1')
    pid = JSON.parse(last_response.body)['id']
    resolve(pid)
    assert_equal 'completed', status_of('i1')
    # The archive rode set_status, so the transition journal was appended.
    transitions = Item.get('i1').json['transitions']
    assert_equal 1, transitions.size
    assert_equal 'completed', transitions.last['to']
  end

  def test_board_born_item_does_not_archive_until_all_placements_resolve
    assign('i1')                                   # DATE
    first = JSON.parse(last_response.body)['id']
    assign('i1', date: '2026-07-23')               # second day
    second = JSON.parse(last_response.body)['id']

    resolve(first)
    assert_equal 'want-to', status_of('i1')        # one still open — no archive

    resolve(second)
    assert_equal 'completed', status_of('i1')      # both resolved — archive
  end

  def test_skipping_the_last_open_placement_archives_a_one_off
    # A skip resolves too (§2.3/§4.4), so a mix of complete + skip closes the set.
    assign('i1')
    first = JSON.parse(last_response.body)['id']
    assign('i1', date: '2026-07-23')
    second = JSON.parse(last_response.body)['id']

    resolve(first, 'completed')
    resolve(second, 'skipped')
    assert_equal 'completed', status_of('i1')
  end

  def test_shelf_item_does_not_auto_archive_on_placement_resolution
    List.new({'id' => 'l1', 'name' => 'Shelf', 'items' => ['i1']}).save!
    assign('i1')
    pid = JSON.parse(last_response.body)['id']
    resolve(pid)
    # A shelf (reusable) item is not a one-off — resolving an instance leaves its
    # lifecycle untouched (a `doing` game completing a session stays `doing`).
    assert_equal 'want-to', status_of('i1')
  end

  def test_auto_archive_is_idempotent
    assign('i1')
    pid = JSON.parse(last_response.body)['id']
    resolve(pid)
    assert_equal 'completed', status_of('i1')
    assert_equal 1, Item.get('i1').json['transitions'].size

    resolve(pid)                                   # re-resolve: already terminal
    assert_equal 'completed', status_of('i1')
    assert_equal 1, Item.get('i1').json['transitions'].size  # no duplicate transition
  end

  def test_reopening_a_placement_does_not_re_archive
    assign('i1')
    pid = JSON.parse(last_response.body)['id']
    resolve(pid, nil)                              # resolution:nil never resolves
    assert_equal 'want-to', status_of('i1')
  end

  # ── Defer (PR 9c) — "not this week, yes next" +1 week marker ─────────────────

  WEEK_START = '2026-07-27'   # a Monday; +1 week = 2026-08-03

  def defer(pid, week_start: WEEK_START)
    post("/api/placements/#{pid}/defer",
         { 'week_start' => week_start }.to_json, { 'Content-Type' => 'application/json' })
  end

  def test_defer_sets_not_before_one_week_out
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    defer(pid)
    assert_equal 200, last_response.status
    deferred = JSON.parse(last_response.body)
    assert_equal '2026-08-03', deferred['not_before']   # strictly +1 week
    assert_equal true, deferred['floating']              # still floating
  end

  def test_defer_stamps_origin_date_when_absent
    # A never-dated staged task has no origin_date; deferring anchors the derived
    # carried-count at this week's start so it starts counting ("one number, not two").
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    assert_nil JSON.parse(last_response.body)['origin_date']
    defer(pid)
    assert_equal WEEK_START, JSON.parse(last_response.body)['origin_date']
  end

  def test_defer_preserves_an_existing_origin_date
    # A carried task already has an origin_date — deferring must not overwrite it.
    assign('i1')                                   # dated → stamps origin_date = DATE
    pid = JSON.parse(last_response.body)['id']
    defer(pid)
    assert_equal DATE, JSON.parse(last_response.body)['origin_date']
  end

  def test_defer_requires_a_week_start
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    post("/api/placements/#{pid}/defer", {}.to_json, { 'Content-Type' => 'application/json' })
    assert_equal 400, last_response.status
  end

  def test_defer_unknown_placement_is_not_found
    defer('nope')
    assert_equal 404, last_response.status
  end

  # ── Delete (PR 9c) — "gone entirely" ─────────────────────────────────────────

  def test_delete_removes_a_floating_placement
    # The gap remove_from_date can't cover: deleting a floating (dateless) placement.
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    delete("/api/placements/#{pid}")
    assert_equal 200, last_response.status
    assert_equal 0, Placement.for_item('i1').size
  end

  def test_delete_removes_the_orphan_board_born_item
    # A board-born one-off (no shelf home, single placement) is gone entirely — item too.
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    delete("/api/placements/#{pid}")
    assert_nil Item.get('i1')
  end

  def test_delete_keeps_a_shelf_items_item
    List.new({'id' => 'l1', 'name' => 'Shelf', 'items' => ['i1']}).save!
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    delete("/api/placements/#{pid}")
    assert_equal 0, Placement.for_item('i1').size
    refute_nil Item.get('i1')                       # shelf item survives
  end

  def test_delete_keeps_the_item_when_other_placements_remain
    stage('i1')                                      # floating
    pid = JSON.parse(last_response.body)['id']
    assign('i1')                                     # a second, dated placement
    delete("/api/placements/#{pid}")
    assert_equal 1, Placement.for_item('i1').size    # the dated one remains
    refute_nil Item.get('i1')                        # item survives — set not empty
  end

  def test_delete_unknown_placement_is_not_found
    delete('/api/placements/nope')
    assert_equal 404, last_response.status
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
