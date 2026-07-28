require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/scheduling'

class SchedulingTest < MinitestWrapper

  def test_type_match_requires_a_known_type_in_an_object
    assert Scheduling.type_match?({'type' => 'event'})
    assert Scheduling.type_match?({'type' => 'task'})
    refute Scheduling.type_match?({'type' => 'bogus'})
    refute Scheduling.type_match?({})            # no type
    refute Scheduling.type_match?('event')       # bare enum, not the object shape
  end

  def test_type_of_defaults_to_task_when_absent
    assert_equal 'task', Scheduling.type_of(nil)
    assert_equal 'task', Scheduling.type_of({'type' => 'task'})
    assert_equal 'event', Scheduling.type_of({'type' => 'event'})
  end

  def test_event_and_task_predicates_read_the_item
    task = Item.new({'id' => 't', 'name' => 'T'})                              # absent => task
    event = Item.new({'id' => 'e', 'name' => 'E', 'scheduling' => {'type' => 'event'}})
    assert Scheduling.task?(task)
    refute Scheduling.event?(task)
    assert Scheduling.event?(event)
    refute Scheduling.task?(event)
  end

  def test_item_persists_scheduling_and_rejects_a_bad_kind
    event = Item.new({'id' => 'e', 'name' => 'E', 'scheduling' => {'type' => 'event'}})
    event.validate
    event.save!
    assert_equal 'event', Item.get('e').json['scheduling']['type']

    assert_raises(Schema::ValidationError) do
      Item.new({'id' => 'b', 'name' => 'B', 'scheduling' => {'type' => 'nope'}}).validate
    end
  end

  def test_item_without_scheduling_still_validates
    Item.new({'id' => 'plain', 'name' => 'Plain'}).validate    # absent is allowed
  end

end
