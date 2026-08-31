require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/scheduling'

# The scheduling object after the event/task kind was deleted (0076): it validates a
# SHAPE and nothing more. The kind's own tests are gone with it.
class SchedulingTest < MinitestWrapper

  def test_type_match_requires_an_object
    assert Scheduling.type_match?({})
    assert Scheduling.type_match?({'recurrence' => {
      'cadence' => 'weekly', 'interval' => 2, 'mode' => 'absolute',
      'anchor' => { 'kind' => 'floating' }, 'collection_id' => 'c1',
      'active' => true, 'start_date' => '2026-07-06',
    }})
    refute Scheduling.type_match?('event')     # a bare string, not the object shape
    refute Scheduling.type_match?(nil)
  end

  # An item stored before the kind was deleted still carries `type` in its json. It has to
  # keep validating — this is the whole reason no migration was needed.
  def test_a_legacy_type_key_is_inert_and_still_validates
    Item.new({'id' => 'old', 'name' => 'Old', 'scheduling' => {'type' => 'event'}}).tap(&:validate).save!
    assert_equal 'event', Item.get('old').json['scheduling']['type']
  end

  def test_a_bad_recurrence_still_fails
    assert_raises(Schema::ValidationError) do
      Item.new({'id' => 'b', 'name' => 'B', 'scheduling' => {'recurrence' => 'nope'}}).validate
    end
  end

  def test_item_without_scheduling_still_validates
    Item.new({'id' => 'plain', 'name' => 'Plain'}).validate    # absent is allowed
  end

end
