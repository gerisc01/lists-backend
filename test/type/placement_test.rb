require_relative '../minitest_wrapper'
require_relative '../helpers'
require_relative '../../src/type/placement'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/type/scheduling'

class PlacementTest < MinitestWrapper

  def setup
    @item = Item.new({'id' => 'i1', 'name' => 'One'})
    @item2 = Item.new({'id' => 'i2', 'name' => 'Two'})
    @collection = Collection.new({'id' => 'c1', 'name' => 'Collection'})
    [@item, @item2, @collection].each(&:save!)
  end

  def new_placement(overrides = {})
    Placement.new({
      'item_id' => @item.id,
      'collection_id' => @collection.id,
      'date' => '2026-07-22',
      'floating' => false,
    }.merge(overrides))
  end

  def test_dated_placement_round_trip
    p = new_placement
    p.validate
    p.save!

    reloaded = Placement.get(p.id)
    refute_nil reloaded.id
    assert_equal @item.id, reloaded.item_id
    assert_equal @collection.id, reloaded.collection_id
    assert_equal '2026-07-22', reloaded.date
    assert_equal false, reloaded.floating
  end

  def test_floating_placement_has_no_date
    p = new_placement({'date' => nil, 'floating' => true})
    p.validate
    p.save!

    reloaded = Placement.get(p.id)
    assert_nil reloaded.date
    assert_equal true, reloaded.floating
  end

  def test_requires_item_and_collection
    assert_raises(Schema::ValidationError) do
      Placement.new({'collection_id' => @collection.id, 'date' => '2026-07-22'}).validate
    end
    assert_raises(Schema::ValidationError) do
      Placement.new({'item_id' => @item.id, 'date' => '2026-07-22'}).validate
    end
  end

  # Referential existence is enforced at the type level via type_ref: a placement
  # pointing at an item/collection that doesn't exist fails validation.
  def test_rejects_unknown_item_ref
    assert_raises(Schema::ValidationError) do
      new_placement({'item_id' => 'does-not-exist'}).validate
    end
  end

  def test_rejects_unknown_collection_ref
    assert_raises(Schema::ValidationError) do
      new_placement({'collection_id' => 'does-not-exist'}).validate
    end
  end

  def test_queries_by_item_and_date
    new_placement.tap(&:validate).save!
    new_placement({'item_id' => @item2.id}).tap(&:validate).save!
    new_placement({'date' => '2026-07-23'}).tap(&:validate).save!

    assert_equal 2, Placement.for_item(@item.id).size
    assert_equal 2, Placement.for_date('2026-07-22').size
    assert_equal 3, Placement.for_date_range('2026-07-22', '2026-07-23').size
    assert_equal 0, Placement.for_date_range('2026-07-24', '2026-07-30').size

    found = Placement.find_dated(@item.id, '2026-07-22', @collection.id)
    refute_nil found
    assert_equal @item.id, found.item_id
  end

  def test_day_view_groups_by_collection_with_priority_subset
    new_placement.tap(&:validate).save!
    new_placement({'item_id' => @item2.id, 'priority' => true}).tap(&:validate).save!

    view = Placement.day_view('2026-07-22')
    assert_equal [@item.id, @item2.id].sort, view['items'][@collection.id].sort
    assert_equal [@item2.id], view['priorities'][@collection.id]
  end

  # ── resolution / origin_date (PR 9a) ────────────────────────────────────────

  def test_resolution_and_origin_date_round_trip
    p = new_placement({'resolution' => 'completed', 'resolved_at' => '2026-07-22T00:00:00Z',
                       'origin_date' => '2026-07-20'})
    p.validate
    p.save!
    reloaded = Placement.get(p.id)
    assert_equal 'completed', reloaded.resolution
    assert_equal '2026-07-22T00:00:00Z', reloaded.resolved_at
    assert_equal '2026-07-20', reloaded.origin_date
  end

  def test_rejects_unknown_resolution
    assert_raises(Schema::ValidationError) do
      new_placement({'resolution' => 'bogus'}).validate
    end
  end

  def test_assignee_and_resolved_by_round_trip
    p = new_placement({'assignee' => 'acct_b', 'resolved_by' => 'acct_a'})
    p.validate
    p.save!
    reloaded = Placement.get(p.id)
    assert_equal 'acct_b', reloaded.assignee
    assert_equal 'acct_a', reloaded.resolved_by
  end

  # Unassigned is the ordinary state, so the field carries no default and an absent
  # value must survive a round trip as absent (never a sentinel).
  def test_placement_is_unassigned_by_default
    p = new_placement
    p.validate
    p.save!
    assert_nil Placement.get(p.id).assignee
  end

  def test_past_only_true_for_a_dated_day_strictly_before
    dated = new_placement({'date' => '2026-07-22'})
    assert dated.past?('2026-07-23')                 # day is over
    refute dated.past?('2026-07-22')                 # same day is still live
    refute dated.past?('2026-07-21')                 # future
    floating = new_placement({'date' => nil, 'floating' => true})
    refute floating.past?('2030-01-01')              # dayless is never past
  end

  # Only an explicit resolution closes a placement. A day passing does not — the event
  # kind that used to make it do so is gone (0076).
  def test_only_an_explicit_resolution_resolves
    past = new_placement({'date' => '2026-07-22'})               # no resolution set
    refute past.resolved?

    %w[completed skipped lapsed].each do |resolution|
      assert new_placement({'resolution' => resolution}).resolved?
    end
  end

  def test_floating_for_collection_only_returns_floating
    new_placement.tap(&:validate).save!                                      # dated
    new_placement({'date' => nil, 'floating' => true}).tap(&:validate).save! # floating, this collection
    other = Collection.new({'id' => 'c2', 'name' => 'Other'}); other.save!
    new_placement({'date' => nil, 'floating' => true, 'collection_id' => other.id})
      .tap(&:validate).save!                                                 # floating, other collection

    floating = Placement.floating_for_collection(@collection.id)
    assert_equal 1, floating.size
    assert_equal @item.id, floating.first.item_id
    assert_nil floating.first.date
    assert_equal true, floating.first.floating
  end

  def test_floating_for_collection_excludes_orphaned_placement
    # A floating placement whose item is later deleted is an orphan — the staging
    # read must not return it (reconcile prunes the dead row for good later).
    new_placement({'date' => nil, 'floating' => true}).tap(&:validate).save!
    assert_equal 1, Placement.floating_for_collection(@collection.id).size

    @item.delete!                                   # soft-delete the item out from under it
    assert_empty Placement.floating_for_collection(@collection.id)
  end

  # ── Cross-collection queries (PR 8) ──────────────────────────────────────────

  def test_floating_for_collections_spans_the_set
    Collection.new({'id' => 'c2', 'name' => 'Two'}).save!
    Collection.new({'id' => 'c3', 'name' => 'Three'}).save!
    new_placement({'date' => nil, 'floating' => true}).tap(&:validate).save!  # c1 floating
    new_placement({'date' => nil, 'floating' => true, 'item_id' => @item2.id, 'collection_id' => 'c2'})
      .tap(&:validate).save!                                                  # c2 floating
    new_placement({'date' => nil, 'floating' => true, 'item_id' => @item2.id, 'collection_id' => 'c3'})
      .tap(&:validate).save!                                                  # c3 floating — not requested
    new_placement.tap(&:validate).save!                                       # c1 dated — excluded

    floating = Placement.floating_for_collections(['c1', 'c2'])
    assert_equal [@collection.id, 'c2'].sort, floating.map(&:collection_id).sort
    assert(floating.all? { |p| p.floating == true && p.date.nil? })
  end

  def test_floating_for_collections_excludes_orphaned_placement
    Collection.new({'id' => 'c2', 'name' => 'Two'}).save!
    new_placement({'date' => nil, 'floating' => true}).tap(&:validate).save!  # c1, @item
    new_placement({'date' => nil, 'floating' => true, 'item_id' => @item2.id, 'collection_id' => 'c2'})
      .tap(&:validate).save!                                                  # c2, @item2
    assert_equal 2, Placement.floating_for_collections(['c1', 'c2']).size

    @item.delete!                                   # only @item's placement is now orphaned
    remaining = Placement.floating_for_collections(['c1', 'c2'])
    assert_equal ['c2'], remaining.map(&:collection_id)
    assert_equal @item2.id, remaining.first.item_id
  end

  def test_day_map_for_collections_groups_by_date_across_the_set
    Collection.new({'id' => 'c2', 'name' => 'Two'}).save!
    new_placement({'date' => '2026-07-22'}).tap(&:validate).save!             # c1 @ 07-22
    new_placement({'date' => '2026-07-22', 'item_id' => @item2.id, 'collection_id' => 'c2'})
      .tap(&:validate).save!                                                  # c2 @ 07-22
    Collection.new({'id' => 'c3', 'name' => 'Three'}).save!
    new_placement({'date' => '2026-07-23', 'item_id' => @item2.id, 'collection_id' => 'c3'})
      .tap(&:validate).save!                                                  # c3 @ 07-23 — not requested

    map = Placement.day_map_for_collections(['c1', 'c2'], '2026-07-20', '2026-07-26')
    refute map.key?('2026-07-23')   # c3 excluded (check before the default-block access below)
    assert_equal [@item.id, @item2.id].sort, map['2026-07-22'].map { |p| p['item_id'] }.sort
  end

  # The grid renders placements, not items: it addresses one by id to write a
  # resolution ("I did this") and reads the resolution back to strike a completed
  # card in place. A resolved placement therefore STAYS in the day map, unlike the
  # floating pile read which filters it out.
  def test_day_map_for_collections_returns_full_placements_including_resolved
    placement = new_placement({'date' => '2026-07-22', 'resolution' => 'completed'})
    placement.validate
    placement.save!

    entry = Placement.day_map_for_collections(['c1'], '2026-07-20', '2026-07-26')['2026-07-22'].first
    assert_equal placement.id, entry['id']
    assert_equal @item.id, entry['item_id']
    assert_equal 'c1', entry['collection_id']
    assert_equal 'completed', entry['resolution']
  end

end
