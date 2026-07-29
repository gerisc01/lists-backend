require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/type/placement'
require_relative '../../src/actions/occurrences'

# PR 12 — the recurrence materializer (shadow). Untouched occurrences are ghosts
# computed for the visible week; a persisted Placement for a period suppresses that
# week's ghost. Absolute weekly, floating + fixed-day. Weeks below are Mondays so the
# grid and phase are explicit; `week_start` both selects the visible week and defines
# the grid.
class OccurrencesTest < MinitestWrapper

  W0 = '2026-07-06'   # Monday — the rule's start_date / anchor week
  W1 = '2026-07-13'
  W2 = '2026-07-20'
  W3 = '2026-07-27'
  W4 = '2026-08-03'
  AS_OF = '2026-07-06'

  def setup
    Collection.new({ 'id' => 'c1', 'name' => 'C' }).save!
  end

  def rule(overrides = {})
    {
      'cadence' => 'weekly', 'interval' => 2, 'mode' => 'absolute',
      'anchor' => { 'kind' => 'floating' }, 'collection_id' => 'c1',
      'active' => true, 'start_date' => W0,
    }.merge(overrides)
  end

  def recurring_item(id, rule_hash)
    Item.new({
      'id' => id, 'name' => id,
      'scheduling' => { 'type' => 'task', 'recurrence' => rule_hash },
    }).tap(&:validate).tap(&:save!)
  end

  def placement(item_id, date, overrides = {})
    Placement.new({
      'item_id' => item_id, 'collection_id' => 'c1',
      'date' => date, 'floating' => false, 'origin_date' => date,
    }.merge(overrides)).tap(&:validate).tap(&:save!)
  end

  def week(week_start, collections: ['c1'], as_of: AS_OF)
    occurrences_for_week(collections, week_start, as_of: as_of)
  end

  # ── Interval phase (every 2 weeks) ───────────────────────────────────────────

  def test_floating_rule_emits_only_on_due_weeks
    recurring_item('trash', rule)

    assert_equal 1, week(W0).length, 'W0 is a due week'
    assert_equal 1, week(W2).length, 'W2 is a due week (2 weeks later)'
    assert_equal 1, week(W4).length, 'W4 is a due week'
    # W1 / W3 are off-phase but the prior occurrence carries (see carry test); the
    # count is still one live occurrence, never two.
    assert_equal 1, week(W1).length
    assert_equal 1, week(W3).length
  end

  def test_a_fresh_floating_occurrence_is_dayless_and_not_carried
    recurring_item('trash', rule)
    ghost = week(W2).first
    assert_equal true, ghost['ghost']
    assert_equal 'trash', ghost['rule_item_id']
    assert_nil ghost['date']
    assert_equal true, ghost['floating']
    assert_equal false, ghost['carried']
    assert_equal W2, ghost['period_start']
    assert_equal W2, ghost['origin_date']
  end

  def test_an_untouched_occurrence_carries_until_the_next_is_due
    recurring_item('trash', rule)
    carried = week(W1).first          # one week after the W0 due-week, before W2
    assert_equal true, carried['carried']
    assert_equal W0, carried['period_start'], 'still the same W0 occurrence, re-floated'
    assert_equal W0, carried['origin_date']
  end

  def test_older_occurrence_expires_when_the_next_comes_due
    recurring_item('trash', rule)
    # At W2 the live occurrence is W2's, not W0's — old one expired, never aggregated.
    assert_equal W2, week(W2).first['period_start']
  end

  def test_before_the_start_date_nothing_is_emitted
    recurring_item('trash', rule)
    assert_empty week('2026-06-29')   # the Monday before W0
  end

  # ── Touched => real (dedup against a persisted placement) ────────────────────

  def test_a_persisted_placement_in_the_period_suppresses_the_ghost
    recurring_item('trash', rule)
    placement('trash', '2026-07-21')  # a real placement inside the W2 due-week
    assert_empty week(W2), 'the persisted row owns the occurrence; no ghost'
    assert_equal 1, week(W4).length, 'later untouched occurrence still ghosts'
  end

  def test_dedup_matches_on_origin_date_even_after_carry_refloat
    recurring_item('trash', rule)
    # A carried real placement: re-floated (date nil) but origin_date anchors its period.
    placement('trash', nil, 'floating' => true, 'origin_date' => '2026-07-22')
    assert_empty week(W2)
  end

  # ── active / paused + collection scoping ─────────────────────────────────────

  def test_a_paused_rule_emits_nothing
    recurring_item('snow', rule('active' => false))
    assert_empty week(W0)
    assert_empty week(W2)
  end

  def test_only_rules_in_the_requested_collections_emit
    recurring_item('trash', rule)                       # collection_id c1
    assert_empty week(W2, collections: ['c2'])
    assert_equal 1, week(W2, collections: ['c1', 'c2']).length
  end

  def test_a_non_recurring_item_never_emits
    Item.new({ 'id' => 'plain', 'name' => 'Plain' }).tap(&:validate).tap(&:save!)
    assert_empty week(W0)
  end

  # ── Fixed-day anchoring ──────────────────────────────────────────────────────

  def test_fixed_day_emits_a_dated_ghost_on_that_weekday
    recurring_item('bins', rule('interval' => 1, 'anchor' => { 'kind' => 'fixed-day', 'weekday' => 2 }))
    ghost = week(W0).first
    assert_equal '2026-07-07', ghost['date'], 'the Tuesday of the W0 (Mon-start) week'
    assert_equal false, ghost['floating']
    assert_equal false, ghost['carried']
  end

  def test_a_carried_fixed_day_occurrence_refloats
    recurring_item('bins', rule('anchor' => { 'kind' => 'fixed-day', 'weekday' => 2 }))
    carried = week(W1).first          # W0's Tuesday occurrence carried into W1
    assert_nil carried['date'], 're-floated, no longer dated'
    assert_equal true, carried['floating']
    assert_equal true, carried['carried']
    assert_equal '2026-07-07', carried['origin_date'], 'keeps its original Tuesday as the anchor'
  end

end
