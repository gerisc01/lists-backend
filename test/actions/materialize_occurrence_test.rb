require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/type/placement'
require_relative '../../src/actions/materialize_occurrence'
require_relative '../../src/actions/occurrences'

# PR 13 — the "touch => real" seam. Materializing a ghost persists a Placement stamped
# origin_date = period_start (the occurrence's due-week), which both makes it idempotent
# and makes occurrences.rb stop emitting the ghost — even when bound to a day in a later
# week (the carried case). Weeks are Mondays so the grid/phase is explicit.
class MaterializeOccurrenceTest < MinitestWrapper

  W2 = '2026-07-20'   # a due-week (the ghost's period_start)
  W3 = '2026-07-27'   # a later week — binding here still resolves the W2 occurrence
  FRI_W3 = '2026-07-31'

  def setup
    Collection.new({ 'id' => 'c1', 'name' => 'C' }).save!
    Item.new({ 'id' => 'trash', 'name' => 'Trash' }).save!
  end

  def rule(overrides = {})
    {
      'cadence' => 'weekly', 'interval' => 2, 'mode' => 'absolute',
      'anchor' => { 'kind' => 'floating' }, 'collection_id' => 'c1',
      'active' => true, 'start_date' => W2,
    }.merge(overrides)
  end

  def recurring_trash
    Item.new({
      'id' => 'trash', 'name' => 'Trash',
      'scheduling' => { 'type' => 'task', 'recurrence' => rule },
    }).tap(&:validate).tap(&:save!)
  end

  # ── Create shapes ────────────────────────────────────────────────────────────

  def test_dated_materialization_stamps_origin_date_to_the_period
    p = materialize_occurrence('trash', 'c1', W2, FRI_W3)
    assert_equal FRI_W3, p.date
    assert_equal false, p.floating
    assert_equal W2, p.origin_date, 'anchored to the due-week, not the bound day'
  end

  def test_floating_materialization_has_no_date_but_keeps_the_period_anchor
    p = materialize_occurrence('trash', 'c1', W2)
    assert_nil p.date
    assert_equal true, p.floating
    assert_equal W2, p.origin_date
  end

  # ── Idempotency ──────────────────────────────────────────────────────────────

  def test_re_materializing_the_same_occurrence_returns_the_same_placement
    first = materialize_occurrence('trash', 'c1', W2, FRI_W3)
    again = materialize_occurrence('trash', 'c1', W2, FRI_W3)
    assert_equal first.id, again.id
    assert_equal 1, Placement.for_item('trash').length, 'no duplicate piled up'
  end

  # ── The point: a materialized occurrence suppresses its ghost ────────────────

  def test_materializing_suppresses_the_ghost_even_when_bound_to_a_later_week
    recurring_trash
    assert_equal 1, occurrences_for_week(['c1'], W2).length, 'ghost present before touch'

    materialize_occurrence('trash', 'c1', W2, FRI_W3)  # bound into W3, a later week

    assert_empty occurrences_for_week(['c1'], W2), 'W2 occurrence now owned by the real placement'
    assert_empty occurrences_for_week(['c1'], W3), 'and not re-emitted in the week it was bound into'
  end

  # ── Guards ───────────────────────────────────────────────────────────────────

  def test_raises_on_missing_item_collection_or_period
    assert_raises(ListError::NotFound)   { materialize_occurrence('nope', 'c1', W2) }
    assert_raises(ListError::NotFound)   { materialize_occurrence('trash', 'nope', W2) }
    assert_raises(ListError::BadRequest) { materialize_occurrence('trash', 'c1', '') }
  end

end
