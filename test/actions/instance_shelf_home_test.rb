require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/collection'
require_relative '../../src/type/list'
require_relative '../../src/type/placement'
require_relative '../../src/actions/auto_archive'
require_relative '../../src/actions/delete_placement'
require_relative '../../src/actions/reconcile'

# An INSTANCE's shelf home is its PARENT's. A playthrough lives in no list — only the
# game does — so a bare id check read every run as board-born, exactly the way it read
# every group member before 0074. The sibling of group_member_shelf_home_test, and the
# same four doors: this pins the two that actually bite, plus the composed case (a run of
# a game that is itself a group member), which is where the loose end was found.
class InstanceShelfHomeTest < MinitestWrapper

  AS_OF = '2026-07-29'   # a Wednesday
  PASTDAY = '2026-07-27' # Monday of the same week — a day gone, the week is not
  LAST_WEEK = '2026-07-27'   # the AS_OF week, seen from the week after it
  NEXT_MONDAY = '2026-08-03' # rollover: the week holding PASTDAY is now behind us

  def setup
    Collection.new({'id' => 'c1', 'name' => 'C'}).save!
    Item.new({'id' => 'kh', 'name' => 'Kingdom Hearts'}).save!
    Item.new({'id' => 'run', 'name' => 'Kingdom Hearts — Playthrough', 'parent' => 'kh'}).save!
    Item.get('kh').tap { |i| i.json['children'] = ['run'] }.save!
  end

  def teardown
    TypeStorage.clear_test_storage
  end

  def shelf_list(items)
    List.new({'id' => 'l1', 'name' => 'Shelf', 'items' => items}).save!
  end

  def dated(item_id, date)
    Placement.new({
      'item_id' => item_id, 'collection_id' => 'c1',
      'date' => date, 'floating' => false, 'origin_date' => date,
    }).tap(&:validate).tap(&:save!)
  end

  def test_a_run_has_a_shelf_home_through_its_game
    shelf_list(['kh'])
    assert item_has_shelf_home?('run')
  end

  # The composed case: the game is a group member, so the run is two hops from the list.
  def test_a_run_of_a_grouped_game_has_a_shelf_home_through_both
    ItemGroup.new({'id' => 'g1', 'name' => 'Kingdom Hearts', 'group' => ['kh']}).save!
    shelf_list(['g1'])
    assert item_has_shelf_home?('run')
  end

  def test_a_run_of_a_board_born_item_is_still_homeless
    Item.new({'id' => 'other', 'name' => 'other'}).save!
    shelf_list(['other'])
    refute item_has_shelf_home?('run')
  end

  # The bug this was found through: a session placed on a day now past struck the card
  # through on the board, which is the completed treatment for something never played.
  def test_a_past_session_does_not_lapse_the_run
    shelf_list(['kh'])
    p = dated('run', PASTDAY)

    result = reconcile(as_of_date: AS_OF)

    assert_empty result['lapsed']
    assert_nil Placement.get(p.id).resolution
  end

  # Rollover, simulated rather than waited for. A run staged and never played is left in
  # the pile when the week turns: the PLACEMENT is released like any shelf item's, and the
  # run survives untouched — open, unstarted, and still the one staging will find next
  # week. Releasing it is what stops an unplayed week from silently becoming a played one.
  def test_a_run_left_in_the_pile_is_released_at_rollover_and_survives
    shelf_list(['kh'])
    p = Placement.new({
      'item_id' => 'run', 'collection_id' => 'c1',
      'floating' => true, 'staged_week' => LAST_WEEK,
    }).tap(&:validate).tap(&:save!)

    result = reconcile(as_of_date: NEXT_MONDAY)

    assert_equal [p.id], result['released']
    assert_empty result['lapsed']
    assert_empty result['archived']
    assert_nil Placement.get(p.id)
    refute_nil Item.get('run')
    assert_nil Item.get('run').json['started']
    assert_equal 'want-to', Item.get('run').json['status']
    assert_equal 'want-to', Item.get('kh').json['status']
  end

  # The dated half of the same rollover: a session on a day that is now a week behind is
  # left exactly as it was — no resolution written. A shelf item's past days are the
  # record of the week, not a backlog to clear.
  def test_a_past_weeks_session_is_left_alone_at_rollover
    shelf_list(['kh'])
    p = dated('run', PASTDAY)

    result = reconcile(as_of_date: NEXT_MONDAY)

    assert_empty result['lapsed']
    assert_empty result['released']
    assert_nil Placement.get(p.id).resolution
    refute_nil Placement.get(p.id).date
  end

  # Remove on the last session used to delete the run itself, taking its start date and
  # its place in the ledger with it.
  def test_removing_a_runs_last_placement_keeps_the_run
    shelf_list(['kh'])
    p = dated('run', PASTDAY)

    delete_placement(p.id)

    refute_nil Item.get('run')
    assert_equal ['run'], Item.get('kh').children
  end
end
