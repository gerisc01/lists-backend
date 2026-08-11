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

  # A manually staged (pile) placement: dayless AND origin-less — only staged_week —
  # which is exactly what create_floating_placement writes.
  def staged_placement(item_id, staged_week)
    Placement.new({
      'item_id' => item_id, 'collection_id' => 'c1',
      'date' => nil, 'floating' => true, 'staged_week' => staged_week,
    }).tap(&:validate).tap(&:save!)
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
    # W1 / W3 are off-phase. Viewed from W0 they are still in the FUTURE, so the W0
    # occurrence does not carry into them (see the future-carry tests) — an off week you
    # haven't reached yet is empty. Standing IN W1, the carry does apply (carry test below);
    # either way it is one live occurrence, never two.
    assert_empty week(W1)
    assert_empty week(W3)
    assert_equal 1, week(W1, as_of: W1).length
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
    # Standing in W1: one week after the W0 due-week, before W2. The W0 occurrence went
    # untouched, so it is still on the plate and rides into the week you're now in.
    carried = week(W1, as_of: W1).first
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

  # ── end_date (bound the series going forward) ────────────────────────────────

  def test_an_occurrence_due_in_the_end_week_still_emits
    # end_date sits inside the W2 due-week (Wed of the 07-20 Mon-start week).
    recurring_item('trash', rule('end_date' => '2026-07-22'))
    assert_equal 1, week(W2).length, 'the occurrence whose period is the end week still shows'
  end

  def test_after_the_end_week_nothing_is_emitted
    recurring_item('trash', rule('end_date' => '2026-07-22'))
    assert_empty week(W4), 'no new period starts after the end week'
  end

  def test_a_pre_end_occurrence_does_not_carry_past_the_end_week
    # Without end_date, W2's occurrence carries into W3 (see the carry test). With the
    # series ended in the W2 week, the carry is cut — nothing lingers past the end.
    recurring_item('trash', rule('end_date' => '2026-07-22'))
    assert_empty week(W3, as_of: W3)
  end

  # ── No backfill (the pause/resume concern) ───────────────────────────────────

  def test_no_backfill_however_long_since_the_rule_started
    # The crux of "unpause won't dump 3 months of missed events": occurrences are computed
    # on read, never stored, and AT MOST ONE live occurrence exists per week. So however far
    # past the start you look — e.g. resuming a long-paused weekly rule — a week shows exactly
    # one occurrence, never a backlog of every elapsed period.
    recurring_item('chore', rule('interval' => 1))     # weekly
    far = (::Date.parse(W0) + 84).iso8601              # ~12 weeks after start
    assert_equal 1, week(far, as_of: far).length, 'one occurrence, not a 12-week pile'
  end

  def test_resuming_a_paused_rule_surfaces_only_the_current_occurrence
    # Paused (active:false) emits nothing, however far out you look. Resuming is just
    # active:true again — the same read then yields the single current occurrence (the weeks
    # it was paused simply never emitted; there is nothing to catch up).
    far = (::Date.parse(W0) + 84).iso8601
    recurring_item('chore', rule('interval' => 1, 'active' => false))
    assert_empty week(far, as_of: far), 'paused: nothing emits'

    Item.get('chore').tap { |i| i.json['scheduling']['recurrence']['active'] = true }.save!
    assert_equal 1, week(far, as_of: far).length, 'resumed: just the current one'
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
    carried = week(W1, as_of: W1).first   # W0's Tuesday occurrence carried into W1
    assert_nil carried['date'], 're-floated, no longer dated'
    assert_equal true, carried['floating']
    assert_equal true, carried['carried']
    assert_equal '2026-07-07', carried['origin_date'], 'keeps its original Tuesday as the anchor'
  end

  # ── Carry never projects into the future ─────────────────────────────────────
  # Carry-until-due says "you didn't get to it, it's still on your plate" — a claim about
  # weeks you have already lived through. Looking AHEAD, an occurrence appears only in the
  # week it is actually due, so an every-2-weeks rule leaves the off weeks empty.

  def test_an_occurrence_does_not_carry_into_a_future_week
    recurring_item('trash', rule)
    assert_empty week(W1, as_of: W0), 'W1 is next week — the W0 occurrence is not carried ahead into it'
    assert_empty week(W3, as_of: W0)
  end

  def test_a_future_due_week_still_emits_its_own_occurrence
    recurring_item('trash', rule)
    ghost = week(W2, as_of: W0).first
    assert_equal W2, ghost['period_start'], 'due that week, so it shows even though the week is ahead'
    assert_equal false, ghost['carried']
  end

  def test_a_fixed_day_rule_shows_only_its_day_in_future_due_weeks
    # The reported bug: every 2 weeks on Wednesday showed the Wednesday in due weeks AND a
    # floating copy in the weeks between them.
    recurring_item('bins', rule('anchor' => { 'kind' => 'fixed-day', 'weekday' => 3 }))
    assert_equal '2026-07-22', week(W2, as_of: W0).first['date'], 'the Wednesday of the due week'
    assert_empty week(W1, as_of: W0), 'the off week between them is empty'
    assert_empty week(W3, as_of: W0)
  end

  def test_a_past_off_week_still_shows_the_carry
    # Carry is unchanged for weeks at or before the current one.
    recurring_item('trash', rule)
    assert_equal 1, week(W1, as_of: W2).length, 'looking back at W1 from W2, it was carrying'
  end

  # ── Manually staged placements (no origin_date, no date) ─────────────────────
  # An item staged into the pile by hand and THEN given a rule has a placement with no
  # period of its own. It still represents the occurrence it sits on top of, so the ghost
  # must not be emitted beside it (that showed the item twice in one week).

  def test_a_dayless_staged_placement_in_the_due_week_suppresses_the_ghost
    recurring_item('trash', rule)
    staged_placement('trash', W2)
    assert_empty week(W2), 'the staged card already represents W2\'s occurrence'
  end

  def test_a_dayless_staged_placement_suppresses_a_carried_ghost
    # Staged in W1 while W0's occurrence was carrying into it — same one card.
    recurring_item('trash', rule)
    staged_placement('trash', W1)
    assert_empty week(W1, as_of: W1)
  end

  def test_a_dayless_placement_staged_before_the_due_week_does_not_suppress
    # A stale pile entry from an earlier plan owns nothing — W2's occurrence still ghosts.
    recurring_item('trash', rule)
    staged_placement('trash', W0)
    assert_equal 1, week(W2).length
  end

  def test_a_dayless_placement_with_no_staged_week_suppresses_nothing
    recurring_item('trash', rule)
    Placement.new({ 'item_id' => 'trash', 'collection_id' => 'c1',
                    'date' => nil, 'floating' => true }).tap(&:validate).tap(&:save!)
    assert_equal 1, week(W2).length
  end

  # ── Monthly cadence ──────────────────────────────────────────────────────────
  # Monthly rules ride the same week grid: a due DATE is computed from the month, then
  # mapped onto the caller's grid. Every Monday below is spelled out so the mapping is
  # visible — 2026-07-15 is a Wednesday in the 07-13 week, 2026-08-15 a Saturday in the
  # 08-10 week, which is exactly what makes the week-vs-month distinction observable.

  M_JUL13 = '2026-07-13'    # the week holding Jul 15
  M_AUG3  = '2026-08-03'    # the week BEFORE Aug 15's — August, but not yet due
  M_AUG10 = '2026-08-10'    # the week holding Aug 15
  M_AUG24 = '2026-08-24'    # August's majority "last week" (holds Aug 28)
  M_AUG31 = '2026-08-31'    # holds Aug 31 but is six-sevenths September
  M_SEP14 = '2026-09-14'    # the week holding Sep 15
  M_NOV2  = '2026-11-02'    # November's majority "first week" (holds Nov 4)

  def monthly_rule(overrides = {})
    rule('cadence' => 'monthly', 'interval' => 1,
         'anchor' => { 'kind' => 'date', 'day' => 15 }, 'start_date' => '2026-07-01').merge(overrides)
  end

  def test_a_monthly_date_rule_emits_a_dated_ghost_in_its_due_week
    recurring_item('rent', monthly_rule)
    ghost = week(M_JUL13, as_of: M_JUL13).first
    assert_equal '2026-07-15', ghost['date']
    assert_equal false, ghost['floating']
    assert_equal false, ghost['carried']
    assert_equal M_JUL13, ghost['period_start'], 'the period is the grid week holding the due date'
  end

  def test_a_monthly_occurrence_expires_at_the_next_due_week_not_the_month_boundary
    # The crux. Aug 15 falls in the 08-10 week, so standing in the 08-03 week — already
    # August — July's occurrence is STILL the live one and must keep carrying. Indexing by
    # due MONTH instead of due WEEK would hand August's occurrence over a week early and
    # silently drop July's carry.
    recurring_item('rent', monthly_rule)
    carried = week(M_AUG3, as_of: M_AUG3).first
    assert_equal M_JUL13, carried['period_start'], "still July's, though the month has turned"
    assert_equal true, carried['carried']

    assert_equal M_AUG10, week(M_AUG10, as_of: M_AUG10).first['period_start'], 'now it flips'
  end

  def test_a_carried_monthly_date_occurrence_refloats
    recurring_item('rent', monthly_rule)
    carried = week(M_AUG3, as_of: M_AUG3).first
    assert_nil carried['date'], 're-floated, no longer dated'
    assert_equal true, carried['floating']
    assert_equal '2026-07-15', carried['origin_date'], 'keeps its original day as the anchor'
  end

  def test_a_day_of_month_overflow_clamps_to_the_last_day
    recurring_item('rent', monthly_rule('anchor' => { 'kind' => 'date', 'day' => 31 },
                                        'start_date' => '2026-01-01'))
    assert_equal '2026-02-28', week('2026-02-23', as_of: '2026-02-23').first['date'], 'February clamps'
    # And the clamp must not STICK: chaining Date#>> would leave March on the 28th
    # (Jan 31 >> 1 >> 1 is Mar 28), so March is read separately to prove it is the 31st.
    assert_equal '2026-03-31', week('2026-03-30', as_of: '2026-03-30').first['date']
  end

  def test_a_monthly_interval_skips_the_off_months
    recurring_item('rent', monthly_rule('interval' => 2))     # July, September, ...
    assert_equal M_JUL13, week(M_JUL13, as_of: M_JUL13).first['period_start']
    assert_equal M_JUL13, week(M_AUG10, as_of: M_AUG10).first['period_start'], 'August carries July'
    assert_equal M_SEP14, week(M_SEP14, as_of: M_SEP14).first['period_start']
  end

  def test_a_mid_month_start_date_defers_to_the_next_month
    # Authored Jul 20 with a day-5 anchor: Jul 5 has already passed, so the series must
    # start in August rather than surfacing a two-week-old carry the moment it is created.
    recurring_item('rent', monthly_rule('anchor' => { 'kind' => 'date', 'day' => 5 },
                                        'start_date' => '2026-07-20'))
    assert_empty week(M_JUL13, as_of: '2026-07-20')
    assert_empty week('2026-07-20', as_of: '2026-07-20')
    assert_equal '2026-08-05', week(M_AUG3, as_of: M_AUG3).first['date']
  end

  def test_a_mid_month_start_date_steps_one_month_not_one_interval
    # "Every 3 months on the 5th" authored Aug 10 first fires Sep 5 — the step re-bases the
    # phase onto the first month that actually fires, rather than skipping to November.
    recurring_item('rent', monthly_rule('interval' => 3,
                                        'anchor' => { 'kind' => 'date', 'day' => 5 },
                                        'start_date' => '2026-08-10'))
    assert_equal '2026-09-05', week('2026-08-31', as_of: '2026-08-31').first['date']
  end

  def test_a_monthly_rule_without_a_start_date_phases_from_as_of_without_deferring
    # No start_date is no floor — as_of supplies phase only, mirroring the weekly fallback
    # where the week you are standing in is a due week. Clamping forward here would hide a
    # day-15 rule for a month whenever it was first read after the 15th.
    rule_hash = monthly_rule
    rule_hash.delete('start_date')
    recurring_item('rent', rule_hash)
    assert_equal M_AUG10, week(M_AUG10, as_of: '2026-08-20').first['period_start']
  end

  def test_the_first_week_phase_takes_the_majority_week
    # Nov 1 2026 is a Sunday, so the week containing the 1st starts Oct 26 and is six
    # sevenths October. November's "first week" is the majority week instead.
    recurring_item('kitchen', monthly_rule('anchor' => { 'kind' => 'week-phase', 'phase' => 'first' }))
    assert_equal M_NOV2, week(M_NOV2, as_of: M_NOV2).first['period_start']
    # The 10-26 week is still carrying OCTOBER's occurrence (whose own majority week starts
    # Sep 28) — November's has not come due there, which the naive definition would claim.
    assert_equal '2026-09-28', week('2026-10-26', as_of: '2026-10-26').first['period_start']
  end

  def test_the_last_week_phase_takes_the_majority_week
    # Aug 31 2026 is a Monday, so the week containing the last day is six sevenths
    # September. August's "last week" is the majority week, 08-24.
    recurring_item('kitchen', monthly_rule('anchor' => { 'kind' => 'week-phase', 'phase' => 'last' }))
    assert_equal M_AUG24, week(M_AUG24, as_of: M_AUG24).first['period_start']
    refute_equal M_AUG31, week(M_AUG31, as_of: M_AUG31).first['period_start'],
                 'the 08-31 week belongs to September, not to August\'s last week'
  end

  def test_a_week_phase_occurrence_is_dayless
    recurring_item('kitchen', monthly_rule('anchor' => { 'kind' => 'week-phase', 'phase' => 'first' }))
    ghost = week('2026-08-03', as_of: '2026-08-03').first
    assert_nil ghost['date'], 'you pick the day within that week'
    assert_equal true, ghost['floating']
    assert_equal ghost['period_start'], ghost['origin_date']
  end

  def test_a_monthly_series_respects_end_date
    recurring_item('rent', monthly_rule('end_date' => '2026-07-16'))
    assert_equal 1, week(M_JUL13, as_of: M_JUL13).length, 'the occurrence in the end week still shows'
    assert_empty week(M_AUG10, as_of: M_AUG10), 'no new period after the end week'
  end

  def test_a_persisted_placement_in_the_monthly_period_suppresses_the_ghost
    recurring_item('rent', monthly_rule)
    placement('rent', '2026-07-15')
    assert_empty week(M_JUL13, as_of: M_JUL13)
    assert_equal 1, week(M_AUG10, as_of: M_AUG10).length, 'next month still ghosts'
  end

  def test_a_monthly_occurrence_does_not_carry_into_a_future_week
    recurring_item('rent', monthly_rule)
    assert_empty week(M_AUG3, as_of: M_JUL13), 'looking ahead, the off week is empty'
  end

  def test_before_the_start_month_nothing_is_emitted
    recurring_item('rent', monthly_rule('start_date' => '2026-08-01'))
    assert_empty week(M_JUL13, as_of: M_JUL13)
  end

end
