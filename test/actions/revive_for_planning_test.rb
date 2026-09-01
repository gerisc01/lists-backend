require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/type/placement'
require_relative '../../src/actions/create_floating_placement'
require_relative '../../src/actions/assign_to_date'

# Planning a finished thing means you are not finished with it. The escape hatch for
# "I checked the garage off on Tuesday and then found out it was a bigger job" — made
# next week, with the gesture you were making anyway, instead of a second verb standing
# on every day-view row to serve the rare tap.
class ReviveForPlanningTest < MinitestWrapper

  DATE = '2026-07-29'

  def setup
    Collection.new({'id' => 'c1', 'name' => 'C'}).save!
    Item.new({'id' => 'garage', 'name' => 'Clean the garage', 'status' => 'completed'}).save!
    Item.new({'id' => 'live', 'name' => 'Live thing', 'status' => 'doing'}).save!
  end

  def teardown
    TypeStorage.clear_test_storage
  end

  def test_staging_a_completed_item_revives_it
    create_floating_placement('garage', 'c1')
    assert_equal 'want-to', Item.get('garage').json['status']
  end

  # want-to, not doing: staging is intent, and only the edge into `doing` claims you have
  # begun — which is the edge that stamps an instance's start date.
  def test_the_revival_is_want_to_not_doing
    assign_to_date('garage', DATE, 'c1')
    assert_equal 'want-to', Item.get('garage').json['status']
  end

  def test_the_revival_is_journalled
    create_floating_placement('garage', 'c1')
    transitions = Item.get('garage').json['transitions']
    assert_equal 'completed', transitions.last['from']
    assert_equal 'want-to', transitions.last['to']
  end

  def test_planning_a_live_item_leaves_its_status_alone
    create_floating_placement('live', 'c1')
    assert_equal 'doing', Item.get('live').json['status']
    assert_nil Item.get('live').json['transitions']
  end

  def test_a_retired_item_revives_the_same_way
    Item.get('live').tap { |i| i.json['status'] = 'retired' }.save!
    assign_to_date('live', DATE, 'c1')
    assert_equal 'want-to', Item.get('live').json['status']
  end
end
