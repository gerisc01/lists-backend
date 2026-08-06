require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/recurrence'
require_relative '../../src/type/scheduling'

# PR 12 — the Recurrence validation type. A rule folds into item.scheduling.recurrence
# and the schema enforces its shape server-side (like Status / Resolution / Scheduling).
# Scope: absolute weekly, floating + fixed-day anchoring.
class RecurrenceTest < MinitestWrapper

  def floating_rule(overrides = {})
    {
      'cadence' => 'weekly', 'interval' => 2, 'mode' => 'absolute',
      'anchor' => { 'kind' => 'floating' }, 'collection_id' => 'c1',
      'active' => true, 'start_date' => '2026-07-06',
    }.merge(overrides)
  end

  def fixed_day_rule(overrides = {})
    floating_rule('anchor' => { 'kind' => 'fixed-day', 'weekday' => 2 }).merge(overrides)
  end

  # ── Shape acceptance ─────────────────────────────────────────────────────────

  def test_accepts_a_valid_floating_rule
    assert Recurrence.type_match?(floating_rule)
  end

  def test_accepts_a_valid_fixed_day_rule
    assert Recurrence.type_match?(fixed_day_rule)
  end

  def test_start_date_and_active_are_optional
    rule = floating_rule
    rule.delete('start_date')
    rule.delete('active')
    assert Recurrence.type_match?(rule)
    assert Recurrence.active_of(rule)   # absent active => active
  end

  def test_accepts_an_optional_end_date
    assert Recurrence.type_match?(floating_rule('end_date' => '2026-08-31'))
    assert_equal '2026-08-31', Recurrence.end_date_of(floating_rule('end_date' => '2026-08-31'))
  end

  def test_end_date_is_optional
    rule = floating_rule
    assert Recurrence.type_match?(rule)           # absent end_date => open-ended
    assert_nil Recurrence.end_date_of(rule)
  end

  def test_paused_rule_is_valid_but_inactive
    rule = floating_rule('active' => false)
    assert Recurrence.type_match?(rule)
    refute Recurrence.active_of(rule)
  end

  # ── Shape rejection ──────────────────────────────────────────────────────────

  def test_rejects_non_positive_or_non_integer_interval
    refute Recurrence.type_match?(floating_rule('interval' => 0))
    refute Recurrence.type_match?(floating_rule('interval' => -1))
    refute Recurrence.type_match?(floating_rule('interval' => 1.5))
    refute Recurrence.type_match?(floating_rule('interval' => '2'))
  end

  def test_rejects_unknown_cadence_and_mode
    refute Recurrence.type_match?(floating_rule('cadence' => 'monthly')) # deferred, not yet valid
    refute Recurrence.type_match?(floating_rule('mode' => 'relative'))   # deferred, not yet valid
  end

  def test_rejects_bad_anchor
    refute Recurrence.type_match?(floating_rule('anchor' => { 'kind' => 'date' }))
    refute Recurrence.type_match?(floating_rule('anchor' => { 'kind' => 'fixed-day' }))          # missing weekday
    refute Recurrence.type_match?(floating_rule('anchor' => { 'kind' => 'fixed-day', 'weekday' => 7 }))
    refute Recurrence.type_match?(floating_rule('anchor' => 'floating'))                          # not an object
  end

  def test_rejects_missing_collection_id
    rule = floating_rule
    rule.delete('collection_id')
    refute Recurrence.type_match?(rule)
  end

  def test_rejects_unparseable_start_date_and_non_boolean_active
    refute Recurrence.type_match?(floating_rule('start_date' => 'not-a-date'))
    refute Recurrence.type_match?(floating_rule('active' => 'yes'))
  end

  def test_rejects_unparseable_end_date
    refute Recurrence.type_match?(floating_rule('end_date' => 'not-a-date'))
  end

  # ── Enforced through the Item schema (via Scheduling) ────────────────────────

  def test_item_persists_a_recurrence_rule
    item = Item.new({
      'id' => 'r', 'name' => 'Trash',
      'scheduling' => { 'type' => 'task', 'recurrence' => floating_rule },
    })
    item.validate
    item.save!
    assert Scheduling.recurring?(Item.get('r'))
    assert Scheduling.active_recurrence?(Item.get('r'))
  end

  def test_item_rejects_a_malformed_recurrence_rule
    assert_raises(Schema::ValidationError) do
      Item.new({
        'id' => 'bad', 'name' => 'Bad',
        'scheduling' => { 'type' => 'task', 'recurrence' => floating_rule('interval' => 0) },
      }).validate
    end
  end

  def test_paused_item_is_recurring_but_not_active
    item = Item.new({
      'id' => 'p', 'name' => 'Snow',
      'scheduling' => { 'type' => 'task', 'recurrence' => floating_rule('active' => false) },
    })
    item.validate
    item.save!
    assert Scheduling.recurring?(Item.get('p'))
    refute Scheduling.active_recurrence?(Item.get('p'))
  end

  def test_plain_scheduling_without_recurrence_still_validates
    Item.new({ 'id' => 'plain', 'name' => 'Plain', 'scheduling' => { 'type' => 'task' } }).validate
  end

end
