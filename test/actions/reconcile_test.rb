require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/type/list'
require_relative '../../src/type/placement'
require_relative '../../src/actions/reconcile'

# The reconcile primitive under the weekly-plan reframe (docs/DECISIONS.md "Weekly
# planning is a weekly PLAN, not a backlog"): reconcile RELEASES the past week instead
# of carrying it forward. A floating shelf item un-stages (deleted, item stays on its
# shelf); a one-off task lapses (resolution 'lapsed', retained) and then auto-archives;
# past events resolve by derivation. `as_of_date` is injected so "a week later" is
# deterministic. AS_OF is a Monday, so its week-start (monday_of) is AS_OF itself.
class ReconcileTest < MinitestWrapper

  AS_OF = '2026-07-27'   # a Monday — monday_of(AS_OF) == AS_OF
  PAST  = '2026-07-20'   # the prior Monday — a week that is over
  NEXT  = '2026-08-03'   # the next Monday — a future week (deferred target)
  TODAY = '2026-07-27'   # the same day — still live, not past
  MIDWEEK = '2026-07-29'          # Wednesday of the AS_OF week
  THIS_WEEK_PAST_DAY = '2026-07-27'  # Monday of that same week — a day gone, week not

  def setup
    @collection = Collection.new({'id' => 'c1', 'name' => 'C'})
    @collection.save!
  end

  def new_item(id, scheduling: nil, list: nil)
    attrs = {'id' => id, 'name' => id}
    attrs['scheduling'] = {'type' => scheduling} if scheduling
    Item.new(attrs).tap(&:save!)
    List.new({'id' => "list-#{id}", 'name' => 'Shelf', 'items' => [id]}).save! if list
    id
  end

  def dated(item_id, date, overrides = {})
    Placement.new({
      'item_id' => item_id, 'collection_id' => 'c1',
      'date' => date, 'floating' => false, 'origin_date' => date,
    }.merge(overrides)).tap(&:validate).tap(&:save!)
  end

  def floating(item_id, overrides = {})
    Placement.new({
      'item_id' => item_id, 'collection_id' => 'c1', 'floating' => true,
    }.merge(overrides)).tap(&:validate).tap(&:save!)
  end

  # ── Release the past week ────────────────────────────────────────────────────

  def test_past_week_floating_shelf_item_is_released
    # A shelf item staged for a past week and untouched un-stages: the placement is
    # deleted, but the item survives on its shelf (its durable home).
    new_item('shelf', list: true)
    p = floating('shelf', 'staged_week' => PAST)

    result = reconcile(as_of_date: AS_OF)
    assert_equal [p.id], result['released']
    assert_nil Placement.get(p.id)                 # un-staged (deleted)
    refute_nil Item.get('shelf')                   # item still exists on its shelf
    assert_equal 'want-to', Item.get('shelf').json['status']
  end

  def test_past_week_floating_one_off_lapses_and_archives
    # A one-off has no shelf to fall back to, so it lapses (retained) rather than being
    # deleted, and its now-closed set auto-archives the item.
    new_item('t')
    p = floating('t', 'staged_week' => PAST)

    result = reconcile(as_of_date: AS_OF)
    assert_equal [p.id], result['lapsed']
    lapsed = Placement.get(p.id)
    refute_nil lapsed                              # retained, not deleted
    assert_equal 'lapsed', lapsed.resolution
    refute_nil lapsed.resolved_at
    assert_equal ['t'], result['archived']
    assert_equal 'completed', Item.get('t').json['status']
  end

  def test_past_week_dated_one_off_task_lapses
    # A dated one-off task left behind by a week that is over also lapses (the old
    # carry-forward is gone).
    new_item('t')
    p = dated('t', PAST)

    result = reconcile(as_of_date: AS_OF)
    assert_equal [p.id], result['lapsed']
    assert_equal 'lapsed', Placement.get(p.id).resolution
    assert_equal ['t'], result['archived']
  end

  # The week is the unit on BOTH arms (0075). A one-off you meant to do on Monday and
  # didn't is still this week's plan on Wednesday — you can pull it to Friday. Closing it
  # a day later marked something undone as resolved AND archived the item to 'completed'.
  def test_a_one_off_missed_earlier_this_week_stays_open
    new_item('t')
    p = dated('t', THIS_WEEK_PAST_DAY)

    result = reconcile(as_of_date: MIDWEEK)
    assert_empty result['lapsed']
    assert_empty result['archived']
    assert_nil Placement.get(p.id).resolution
    assert_equal 'want-to', Item.get('t').json['status']
  end

  def test_lapse_and_release_are_idempotent
    new_item('one_off')
    new_item('shelf', list: true)
    floating('one_off', 'staged_week' => PAST)
    floating('shelf', 'staged_week' => PAST)

    reconcile(as_of_date: AS_OF)
    second = reconcile(as_of_date: AS_OF)          # nothing left open+past
    assert_empty second['lapsed']
    assert_empty second['released']
    assert_equal 1, Placement.for_item('one_off').size  # lapsed row retained, not duplicated
    assert_empty Placement.for_item('shelf')            # released row stays gone
  end

  def test_current_week_staged_items_are_untouched
    new_item('one_off')
    new_item('shelf', list: true)
    a = floating('one_off', 'staged_week' => AS_OF)     # this week — still the active plan
    b = floating('shelf', 'staged_week' => AS_OF)

    result = reconcile(as_of_date: AS_OF)
    assert_empty result['lapsed']
    assert_empty result['released']
    assert_nil Placement.get(a.id).resolution
    refute_nil Placement.get(b.id)
  end

  def test_a_deferred_floating_item_is_left_untouched
    # Defer moves staged_week to a future week; reconcile only releases weeks now past,
    # so a deferred placement is untouched and resurfaces once its week arrives.
    new_item('t')
    p = floating('t', 'staged_week' => NEXT)
    result = reconcile(as_of_date: AS_OF)
    assert_empty result['lapsed']
    assert_empty result['released']
    untouched = Placement.get(p.id)
    assert_equal true, untouched.floating
    assert_equal NEXT, untouched.staged_week
    assert_nil untouched.resolution
    assert_equal 'want-to', Item.get('t').json['status']
  end

  def test_a_still_live_dated_task_does_not_lapse
    new_item('t')
    dated('t', TODAY)                              # same day is not "past"
    result = reconcile(as_of_date: AS_OF)
    assert_empty result['lapsed']
    refute_nil Placement.for_item('t').first.date
  end

  def test_an_already_resolved_placement_is_left_alone
    new_item('t')
    dated('t', PAST, 'resolution' => 'completed')
    result = reconcile(as_of_date: AS_OF)
    assert_empty result['lapsed']
    assert_equal 'completed', Placement.for_item('t').first.resolution
  end

  def test_a_dated_shelf_task_stays_put
    # Only FLOATING shelf placements are released; a dated shelf placement is out of the
    # visible week already (date-scoped) and is left as raw material for a week report.
    new_item('shelf', list: true)
    dated('shelf', PAST)
    result = reconcile(as_of_date: AS_OF)
    assert_empty result['lapsed']
    assert_empty result['released']
    refute_nil Placement.for_item('shelf').first.date
  end

  def test_a_one_off_event_is_not_lapsed_but_archives
    # An event resolves by derivation (past day = resolved), so it is not written as
    # 'lapsed'; its closed set still auto-archives the one-off.
    new_item('e', scheduling: 'event')
    dated('e', PAST)
    result = reconcile(as_of_date: AS_OF)
    assert_empty result['lapsed']
    refute_nil Placement.for_item('e').first.date  # event stays dated
    assert_equal ['e'], result['archived']
  end

  # ── Prune orphaned placements (item deleted out from under them) ─────────────

  def test_prunes_placements_whose_item_was_deleted
    new_item('gone')
    floater = floating('gone')
    dated_p = dated('gone', PAST)
    Item.get('gone').delete!                 # soft-delete the item; both placements orphaned

    result = reconcile(as_of_date: AS_OF)
    assert_equal [floater.id, dated_p.id].sort, result['pruned'].sort
    assert_nil Placement.get(floater.id)     # rows deleted for good
    assert_nil Placement.get(dated_p.id)
  end

  def test_prune_leaves_valid_placements_and_is_idempotent
    new_item('gone')
    floating('gone')
    new_item('keep', list: true)
    kept = floating('keep', 'staged_week' => AS_OF)   # current week — not released
    Item.get('gone').delete!

    reconcile(as_of_date: AS_OF)
    second = reconcile(as_of_date: AS_OF)    # nothing left to prune
    assert_empty second['pruned']
    refute_nil Placement.get(kept.id)        # valid placement untouched
  end

  # ── Auto-archive of past (events + closed sets) ──────────────────────────────

  def test_one_off_event_archives_when_its_day_passes
    new_item('e', scheduling: 'event')
    dated('e', PAST)                     # a past event is resolved by derivation
    result = reconcile(as_of_date: AS_OF)
    assert_equal ['e'], result['archived']
    assert_equal 'completed', Item.get('e').json['status']
  end

  def test_shelf_event_does_not_archive_on_past
    new_item('e', scheduling: 'event', list: true)
    dated('e', PAST)
    assert_empty reconcile(as_of_date: AS_OF)['archived']
    assert_equal 'want-to', Item.get('e').json['status']
  end

  def test_reconcile_is_idempotent_across_runs
    new_item('e', scheduling: 'event')
    dated('e', PAST)
    reconcile(as_of_date: AS_OF)
    second = reconcile(as_of_date: AS_OF)
    assert_empty second['archived']                        # already terminal
    assert_equal 1, Item.get('e').json['transitions'].size # no duplicate transition
  end

end
