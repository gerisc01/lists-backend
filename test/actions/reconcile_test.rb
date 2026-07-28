require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/type/list'
require_relative '../../src/type/placement'
require_relative '../../src/actions/reconcile'

# PR 9a — the pure, idempotent reconcile primitive: carry-forward lapsed one-off
# tasks, resolve past events (derived), auto-archive one-offs whose sets closed.
# `as_of_date` is injected so "a week later" is deterministic. Dates here sit
# before/after the fixed AS_OF so the past/future split is explicit.
class ReconcileTest < MinitestWrapper

  AS_OF = '2026-07-27'
  PAST  = '2026-07-20'   # strictly before AS_OF — a day that is over
  TODAY = '2026-07-27'   # the same day — still live, not past

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

  # ── Carry-forward ────────────────────────────────────────────────────────────

  def test_lapsed_one_off_task_re_floats_once_preserving_origin
    new_item('t')
    p = dated('t', PAST)

    result = reconcile(as_of_date: AS_OF)
    assert_equal [p.id], result['carried']

    carried = Placement.get(p.id)
    assert_nil carried.date              # re-floated: date cleared
    assert_equal true, carried.floating  # ...and floating set
    assert_equal PAST, carried.origin_date  # origin preserved as the immutable anchor
  end

  def test_carry_forward_is_idempotent
    new_item('t')
    dated('t', PAST)

    reconcile(as_of_date: AS_OF)
    second = reconcile(as_of_date: AS_OF)   # nothing left dated+past to carry
    assert_empty second['carried']
    assert_equal 1, Placement.for_item('t').size   # no duplicate placement
  end

  def test_a_still_live_or_future_task_does_not_carry
    new_item('t')
    dated('t', TODAY)                    # same day is not "past"
    assert_empty reconcile(as_of_date: AS_OF)['carried']
    refute_nil Placement.for_item('t').first.date
  end

  def test_a_resolved_task_does_not_carry
    new_item('t')
    dated('t', PAST, 'resolution' => 'completed')
    assert_empty reconcile(as_of_date: AS_OF)['carried']
  end

  def test_an_event_does_not_carry
    new_item('e', scheduling: 'event')
    dated('e', PAST)
    assert_empty reconcile(as_of_date: AS_OF)['carried']
    refute_nil Placement.for_item('e').first.date   # event stays dated
  end

  def test_a_shelf_task_does_not_carry
    # Carry-forward is one-off-only — a reusable shelf item's lapsed plan stays put.
    new_item('shelf', list: true)
    dated('shelf', PAST)
    assert_empty reconcile(as_of_date: AS_OF)['carried']
    refute_nil Placement.for_item('shelf').first.date
  end

  # ── Auto-archive of past (events + closed sets) ──────────────────────────────

  def test_one_off_event_archives_when_its_day_passes
    new_item('e', scheduling: 'event')
    dated('e', PAST)                     # a past event is resolved by derivation
    result = reconcile(as_of_date: AS_OF)
    assert_equal ['e'], result['archived']
    assert_equal 'completed', Item.get('e').json['status']
  end

  def test_carried_task_does_not_archive
    # After carry the task is floating+open, so its set is not resolved — no archive.
    new_item('t')
    dated('t', PAST)
    result = reconcile(as_of_date: AS_OF)
    assert_empty result['archived']
    assert_equal 'want-to', Item.get('t').json['status']
  end

  def test_shelf_event_does_not_archive_on_past
    new_item('e', scheduling: 'event', list: true)
    dated('e', PAST)
    assert_empty reconcile(as_of_date: AS_OF)['archived']
    assert_equal 'want-to', Item.get('e').json['status']
  end

  def test_a_deferred_floating_task_is_left_untouched
    # A deferred one-off (PR 9c) is floating with a future not_before marker. It has no
    # date, so carry-forward (dated+past only) never touches it, and its open resolution
    # blocks auto-archive — reconcile leaves it exactly as staged.
    new_item('t')
    p = floating('t', 'not_before' => '2026-08-03', 'origin_date' => PAST)
    result = reconcile(as_of_date: AS_OF)
    assert_empty result['carried']
    assert_empty result['archived']
    untouched = Placement.get(p.id)
    assert_equal true, untouched.floating
    assert_equal '2026-08-03', untouched.not_before
    assert_equal 'want-to', Item.get('t').json['status']
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
