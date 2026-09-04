require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/placement'
require_relative '../../src/type/day'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/collection'
require_relative '../../src/type/list'
require_relative '../../src/type/account'

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
    assert_equal %w[i1 i2].sort, map[DATE].map { |p| p['item_id'] }.sort
    assert_equal %w[i3], map['2026-07-24'].map { |p| p['item_id'] }
  end

  def test_collection_range_read_excludes_other_collections
    other = Collection.new({'id' => 'c2', 'name' => 'Other'}); other.save!
    assign('i1')                        # c1
    assign('i2', collection: 'c2')      # c2
    get("/api/collections/c1/placements?start=2026-07-20&end=2026-07-26")
    map = JSON.parse(last_response.body)
    assert_equal %w[i1], map[DATE].map { |p| p['item_id'] }
  end

  def test_collection_range_read_requires_start_and_end
    get("/api/collections/c1/placements")
    assert_equal 400, last_response.status
  end

  # ── Floating placements + bind (5c) ─────────────────────────────────────────

  WEEK = '2026-07-27'         # a Monday — a valid staged_week
  NEXT_WEEK = '2026-08-03'    # the following Monday

  def stage(item_id, collection: 'c1', staged_week: nil)
    body = { 'collection' => collection }
    body['staged_week'] = staged_week if staged_week
    post("/api/items/#{item_id}/placements", body.to_json,
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

  # A GROUP is one row in a list but never carries a placement — a Placement's item_id
  # always names an Item. Staging one stages the member you'd actually pick up, so the
  # pile ends up holding "Yakuza 3", not "the Yakuza series". This used to 404, because
  # the guard was Item.exist? and a group lives in its own store.
  def test_staging_a_group_stages_its_next_member
    Item.get('i1').tap { |it| it.json['status'] = 'completed'; it.save! }
    ItemGroup.new({'id' => 'g1', 'name' => 'Yakuza series', 'group' => %w[i1 i2]}).save!

    stage('g1')

    assert_equal 200, last_response.status
    assert_equal 'i2', JSON.parse(last_response.body)['item_id']
  end

  def test_dating_a_group_dates_its_next_member
    ItemGroup.new({'id' => 'g1', 'name' => 'Yakuza series', 'group' => %w[i1 i2]}).save!

    assign('g1')

    assert_equal 200, last_response.status
    assert_equal 'i1', JSON.parse(last_response.body)['item_id']
  end

  # The group itself must never end up on a placement, so a group with nothing left to
  # do is a clear error rather than a placement pointing at a group id.
  def test_staging_a_finished_group_is_rejected
    @items.first(2).each { |it| it.json['status'] = 'completed'; it.save! }
    ItemGroup.new({'id' => 'g1', 'name' => 'Yakuza series', 'group' => %w[i1 i2]}).save!

    stage('g1')

    assert_equal 400, last_response.status
    assert_equal 0, Placement.floating_for_collection('c1').size
  end

  def test_stage_stamps_staged_week
    stage('i1', staged_week: WEEK)
    assert_equal WEEK, JSON.parse(last_response.body)['staged_week']
  end

  def test_create_floating_is_deduped_per_item_and_collection
    stage('i1')
    first = JSON.parse(last_response.body)['id']
    stage('i1')
    second = JSON.parse(last_response.body)['id']
    assert_equal first, second
    assert_equal 1, Placement.floating_for_collection('c1').size
  end

  def test_restage_restamps_staged_week_on_the_same_placement
    stage('i1', staged_week: WEEK)
    first = JSON.parse(last_response.body)['id']
    stage('i1', staged_week: NEXT_WEEK)          # re-staging means "I want this next week"
    second = JSON.parse(last_response.body)
    assert_equal first, second['id']             # same placement, deduped
    assert_equal NEXT_WEEK, second['staged_week'] # re-stamped to the new week
  end

  def test_cross_collection_floating_read_is_week_scoped
    stage('i1', staged_week: WEEK)
    stage('i2', staged_week: NEXT_WEEK)          # a different week — excluded
    get("/api/placements/floating?collections=c1&week=#{WEEK}")
    assert_equal 200, last_response.status
    floating = JSON.parse(last_response.body)
    assert_equal %w[i1], floating.map { |p| p['item_id'] }
  end

  def test_cross_collection_floating_read_excludes_resolved
    stage('i1', staged_week: WEEK)
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}", { 'resolution' => 'skipped' }.to_json,
          { 'Content-Type' => 'application/json' })
    get("/api/placements/floating?collections=c1&week=#{WEEK}")
    assert_empty JSON.parse(last_response.body)  # a resolved placement leaves the pile
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

  # ── Cross-collection staging pile + mixed grid (PR 8) ───────────────────────

  def test_cross_collection_floating_read_spans_the_requested_set
    Collection.new({'id' => 'c2', 'name' => 'Two'}).save!
    Collection.new({'id' => 'c3', 'name' => 'Three'}).save!
    stage('i1')                               # floating in c1
    stage('i2', collection: 'c2')             # floating in c2
    stage('i3', collection: 'c3')             # floating in c3 — not requested
    assign('i4')                              # dated in c1 — excluded (not floating)
    get('/api/placements/floating?collections=c1,c2')
    assert_equal 200, last_response.status
    floating = JSON.parse(last_response.body)
    assert_equal %w[i1 i2].sort, floating.map { |p| p['item_id'] }.sort
    # source collection provenance is present for grouping
    assert_equal({ 'i1' => 'c1', 'i2' => 'c2' },
                 floating.map { |p| [p['item_id'], p['collection_id']] }.to_h)
  end

  def test_cross_collection_floating_read_flags_one_offs
    List.new({'id' => 'l1', 'name' => 'Shelf', 'items' => ['i1']}).save!
    stage('i1')                               # i1 has a shelf home
    stage('i2')                               # i2 is board-born (no list)
    get('/api/placements/floating?collections=c1')
    floating = JSON.parse(last_response.body)
    one_off = floating.map { |p| [p['item_id'], p['one_off']] }.to_h
    assert_equal false, one_off['i1']
    assert_equal true, one_off['i2']
  end

  # A staged group MEMBER is not board-born: only the group id sits in `list.items`, so
  # the naive check read every member as homeless and the pile bucketed it under
  # "One-offs" instead of its own collection.
  def test_a_staged_group_member_is_not_flagged_one_off
    ItemGroup.new({'id' => 'g1', 'name' => 'Pegboard', 'group' => %w[i1 i2]}).save!
    List.new({'id' => 'l1', 'name' => 'Shelf', 'items' => ['g1']}).save!
    stage('i2')

    get('/api/placements/floating?collections=c1')
    floating = JSON.parse(last_response.body)

    assert_equal 'i2', floating.first['item_id']
    assert_equal false, floating.first['one_off']
  end

  def test_cross_collection_floating_read_requires_collections
    get('/api/placements/floating')
    assert_equal 400, last_response.status
    get('/api/placements/floating?collections=')
    assert_equal 400, last_response.status
  end

  def test_cross_collection_range_read_spans_the_set_and_keeps_provenance
    Collection.new({'id' => 'c2', 'name' => 'Two'}).save!
    Collection.new({'id' => 'c3', 'name' => 'Three'}).save!
    assign('i1')                              # c1 @ DATE
    assign('i2', collection: 'c2')            # c2 @ DATE
    assign('i3', collection: 'c3')            # c3 @ DATE — not requested
    get('/api/placements?collections=c1,c2&start=2026-07-20&end=2026-07-26')
    assert_equal 200, last_response.status
    map = JSON.parse(last_response.body)
    assert_equal %w[i1 i2].sort, map[DATE].map { |p| p['item_id'] }.sort
    assert map[DATE].all? { |p| p['id'] && p['collection_id'] }, 'each entry is a full placement'
  end

  # The grid addresses a placement by id to write "I did this", and renders a resolved
  # card struck through in place — so the range read must carry both, and must NOT
  # filter resolved placements the way the floating pile read does.
  def test_cross_collection_range_read_carries_id_and_resolution_and_keeps_resolved
    assign('i1')
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}", { 'resolution' => 'completed' }.to_json,
          { 'Content-Type' => 'application/json' })
    assert_equal 200, last_response.status
    get('/api/placements?collections=c1&start=2026-07-20&end=2026-07-26')
    entry = JSON.parse(last_response.body)[DATE].first
    assert_equal pid, entry['id']
    assert_equal 'completed', entry['resolution']
    refute_nil entry['resolved_at']
  end

  def test_cross_collection_range_read_requires_collections_and_dates
    get('/api/placements?start=2026-07-20&end=2026-07-26')
    assert_equal 400, last_response.status
    get('/api/placements?collections=c1')
    assert_equal 400, last_response.status
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

  # ── Assignee / actor ────────────────────────────────────────────────────────

  def test_update_placement_assignee_round_trips_and_clears
    Account.new({'id' => 'acct_b', 'name' => 'Bee'}).save!
    stage('i1')
    pid = JSON.parse(last_response.body)['id']

    patch("/api/placements/#{pid}",
          { 'assignee' => 'acct_b' }.to_json, { 'Content-Type' => 'application/json' })
    assert_equal 200, last_response.status
    assert_equal 'acct_b', JSON.parse(last_response.body)['assignee']

    # nil is "nobody's doing it" — the ordinary state, not an error.
    patch("/api/placements/#{pid}",
          { 'assignee' => nil }.to_json, { 'Content-Type' => 'application/json' })
    assert_nil JSON.parse(last_response.body)['assignee']
  end

  def test_update_placement_rejects_assignee_naming_no_account
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}",
          { 'assignee' => 'nobody' }.to_json, { 'Content-Type' => 'application/json' })
    assert_equal 400, last_response.status
  end

  # resolved_by records who the PLAN said would do it, not who tapped (0084): the
  # person closing a chore is routinely not the person who did it.
  def test_resolution_stamps_the_assignee_not_the_acting_account
    %w[acct_a acct_b].each { |id| Account.new({'id' => id, 'name' => id}).save! }
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}", { 'assignee' => 'acct_b' }.to_json,
          { 'Content-Type' => 'application/json' })

    patch("/api/placements/#{pid}", { 'resolution' => 'completed' }.to_json,
          { 'Content-Type' => 'application/json', 'HTTP_ACCOUNT_ID' => 'acct_a' })
    done = JSON.parse(last_response.body)
    assert_equal 'acct_b', done['resolved_by']
    assert_equal 'acct_b', done['assignee']

    # Reopening drops who closed it, and leaves who it's assigned to alone.
    patch("/api/placements/#{pid}", { 'resolution' => nil }.to_json,
          { 'Content-Type' => 'application/json', 'HTTP_ACCOUNT_ID' => 'acct_a' })
    reopened = JSON.parse(last_response.body)
    assert_nil reopened['resolved_by']
    assert_equal 'acct_b', reopened['assignee']
  end

  # An unassigned placement resolves to its item's owner (0083), so the stamp follows
  # the same fallback everything else reads through.
  def test_resolution_falls_back_to_the_items_owner
    %w[acct_a acct_b].each { |id| Account.new({'id' => id, 'name' => id}).save! }
    item = Item.get('i1')
    item.owner = 'acct_b'
    item.save!
    stage('i1')
    pid = JSON.parse(last_response.body)['id']

    patch("/api/placements/#{pid}", { 'resolution' => 'completed' }.to_json,
          { 'Content-Type' => 'application/json', 'HTTP_ACCOUNT_ID' => 'acct_a' })
    assert_equal 'acct_b', JSON.parse(last_response.body)['resolved_by']
  end

  # Nobody named it, so the tap is the only name there is — better than none.
  def test_resolution_falls_back_to_the_actor_when_nobody_is_named
    Account.new({'id' => 'acct_a', 'name' => 'acct_a'}).save!
    stage('i1')
    pid = JSON.parse(last_response.body)['id']

    patch("/api/placements/#{pid}", { 'resolution' => 'completed' }.to_json,
          { 'Content-Type' => 'application/json', 'HTTP_ACCOUNT_ID' => 'acct_a' })
    assert_equal 'acct_a', JSON.parse(last_response.body)['resolved_by']
  end

  # Assign-and-close in one call: the stamp reads the assignee arriving in the same
  # request, not the one it is replacing.
  def test_resolution_reads_an_assignee_written_in_the_same_request
    %w[acct_a acct_b].each { |id| Account.new({'id' => id, 'name' => id}).save! }
    stage('i1')
    pid = JSON.parse(last_response.body)['id']

    patch("/api/placements/#{pid}",
          { 'assignee' => 'acct_b', 'resolution' => 'completed' }.to_json,
          { 'Content-Type' => 'application/json', 'HTTP_ACCOUNT_ID' => 'acct_a' })
    assert_equal 'acct_b', JSON.parse(last_response.body)['resolved_by']
  end

  # An unauthenticated write path (e2e) still resolves — it just has no name to stamp.
  def test_resolution_without_an_account_header_is_still_a_resolution
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}", { 'resolution' => 'completed' }.to_json,
          { 'Content-Type' => 'application/json' })
    assert_equal 200, last_response.status
    done = JSON.parse(last_response.body)
    assert_equal 'completed', done['resolution']
    assert_nil done['resolved_by']
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

  # ── Current assignees (the catalog's assignment read) ───────────────────────

  def current(collections = 'c1')
    get("/api/placements/current?collections=#{collections}")
    JSON.parse(last_response.body)
  end

  def assign_to(pid, account)
    patch("/api/placements/#{pid}", { 'assignee' => account }.to_json,
          { 'Content-Type' => 'application/json' })
  end

  def account!(id)
    Account.new({ 'id' => id, 'name' => id }).save!
    id
  end

  def test_current_returns_only_items_an_occurrence_names
    account!('acct_a')
    assign('i1')
    assign_to(JSON.parse(last_response.body)['id'], 'acct_a')
    assign('i2')   # placed, but nobody claimed it

    assert_equal({ 'i1' => 'acct_a' }, current)
  end

  def test_current_requires_a_collection
    get('/api/placements/current')
    assert_equal 400, last_response.status
  end

  def test_current_ignores_collections_not_asked_for
    account!('acct_a')
    Collection.new({ 'id' => 'c2', 'name' => 'Other' }).save!
    assign('i1', collection: 'c2')
    assign_to(JSON.parse(last_response.body)['id'], 'acct_a')

    assert_equal({}, current('c1'))
    assert_equal({ 'i1' => 'acct_a' }, current('c2'))
  end

  # The plan is the answer: a live occurrence nobody claimed resolves to the OWNER,
  # so a finished one must not speak over it.
  def test_current_prefers_an_open_occurrence_over_a_resolved_one
    account!('acct_a')
    assign('i1', date: '2026-07-20')
    resolve(JSON.parse(last_response.body)['id'])
    assign_to(Placement.for_item('i1').first.id, 'acct_a')
    assign('i1', date: '2026-07-22')   # open, unclaimed

    assert_equal({}, current)
  end

  def test_current_takes_the_soonest_open_occurrence_that_names_somebody
    %w[acct_a acct_b].each { |id| account!(id) }
    assign('i1', date: '2026-07-24')
    assign_to(JSON.parse(last_response.body)['id'], 'acct_b')
    assign('i1', date: '2026-07-22')
    assign_to(JSON.parse(last_response.body)['id'], 'acct_a')

    assert_equal({ 'i1' => 'acct_a' }, current)
  end

  # A floating placement has no day, so it must not read as "today" and outrank a
  # dated one.
  def test_current_sorts_a_floating_occurrence_after_every_dated_one
    %w[acct_a acct_b].each { |id| account!(id) }
    stage('i1')
    assign_to(JSON.parse(last_response.body)['id'], 'acct_b')
    assign('i1', date: '2026-07-22')
    assign_to(JSON.parse(last_response.body)['id'], 'acct_a')

    assert_equal({ 'i1' => 'acct_a' }, current)
  end

  def test_current_falls_back_to_the_last_resolved_occurrence
    %w[acct_a acct_b].each { |id| account!(id) }
    assign('i1', date: '2026-07-20')
    first = JSON.parse(last_response.body)['id']
    assign_to(first, 'acct_a')
    resolve(first)

    assign('i1', date: '2026-07-22')
    second = JSON.parse(last_response.body)['id']
    assign_to(second, 'acct_b')
    resolve(second)

    assert_equal({ 'i1' => 'acct_b' }, current)
  end

  # A rule will emit a fresh, unclaimed occurrence — last week's name is not a claim
  # on next week's.
  def test_current_says_nothing_for_a_recurring_item_with_nothing_open
    account!('acct_a')
    item = Item.get('i1')
    item.json['scheduling'] = {
      'recurrence' => {
        'cadence' => 'weekly', 'interval' => 1, 'mode' => 'absolute',
        'anchor' => { 'kind' => 'floating' }, 'collection_id' => 'c1',
        'active' => true, 'start_date' => '2026-07-20',
      },
    }
    item.save!
    assign('i1', date: '2026-07-20')
    pid = JSON.parse(last_response.body)['id']
    assign_to(pid, 'acct_a')
    resolve(pid)

    assert_equal({}, current)
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

  def test_defer_moves_staged_week_one_week_out
    # Under the weekly-plan reframe (docs/DECISIONS.md) staged_week is the single week
    # anchor, and Defer moves it forward one week — the pile read then shows the
    # placement exactly when the current week reaches that value.
    stage('i1')
    pid = JSON.parse(last_response.body)['id']
    defer(pid)
    assert_equal 200, last_response.status
    deferred = JSON.parse(last_response.body)
    assert_equal '2026-08-03', deferred['staged_week']   # strictly +1 week
    assert_equal true, deferred['floating']              # still floating
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

  # ── Re-float (unbind) — "take it off the day, keep it this week" ─────────────

  def refloat(pid, week_start: WEEK_START)
    post("/api/placements/#{pid}/unbind",
         { 'week_start' => week_start }.to_json, { 'Content-Type' => 'application/json' })
  end

  def test_refloat_flips_dated_back_to_floating
    assign('i1')                                    # dated placement on DATE
    pid = JSON.parse(last_response.body)['id']
    refloat(pid)
    assert_equal 200, last_response.status
    floated = JSON.parse(last_response.body)
    assert_nil floated['date']
    assert_equal true, floated['floating']
    assert_equal WEEK_START, floated['staged_week']  # re-staged into the viewing week
    assert_equal 0, Placement.for_date(DATE).size
    assert_equal 1, Placement.floating_for_collection('c1').size
  end

  def test_refloat_clears_resolution_so_a_lapsed_card_comes_back_open
    # reconcile stamps a passed day's placement `lapsed`; taking it off the day must
    # hand back a clean OPEN floating placement, else the (resolved-excluding) pile
    # read would silently drop it.
    assign('i1')
    pid = JSON.parse(last_response.body)['id']
    patch("/api/placements/#{pid}",
          { 'resolution' => 'skipped' }.to_json, { 'Content-Type' => 'application/json' })
    refloat(pid)
    floated = JSON.parse(last_response.body)
    assert_nil floated['resolution']
    assert_nil floated['resolved_at']
    # and it now surfaces in the week-scoped staging pile
    get("/api/placements/floating?collections=c1&week=#{WEEK_START}")
    assert_equal %w[i1], JSON.parse(last_response.body).map { |p| p['item_id'] }
  end

  def test_refloat_preserves_origin_date
    assign('i1')                                    # first dating stamps origin_date = DATE
    pid = JSON.parse(last_response.body)['id']
    refloat(pid)
    assert_equal DATE, JSON.parse(last_response.body)['origin_date']
  end

  def test_refloat_requires_a_week_start
    assign('i1')
    pid = JSON.parse(last_response.body)['id']
    post("/api/placements/#{pid}/unbind", {}.to_json, { 'Content-Type' => 'application/json' })
    assert_equal 400, last_response.status
  end

  def test_refloat_unknown_placement_is_not_found
    refloat('nope')
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
