require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/actions/resolve_group_member'

class ResolveGroupMemberTest < MinitestWrapper

  def setup
    @plain = Item.new({'id' => 'tacos', 'name' => 'Tacos'})
    @plain.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  # Build a group whose members carry the given statuses, in order. A nil status is
  # stored as no status at all — the birth default is deliberately never persisted.
  def group_with(*statuses)
    ids = statuses.each_with_index.map do |status, i|
      id = "y#{i + 1}"
      fields = {'id' => id, 'name' => "Yakuza #{i + 1}"}
      fields['status'] = status unless status.nil?
      Item.new(fields).save!
      id
    end
    group = ItemGroup.new({'id' => 'yakuza', 'name' => 'Yakuza series', 'group' => ids})
    group.save!
    group
  end

  # The property that lets this sit on the staging path without changing any existing
  # behavior: anything that is not a group comes back untouched.
  def test_a_plain_item_is_returned_unchanged
    assert_equal 'tacos', resolve_group_member('tacos')
  end

  def test_an_unknown_id_is_returned_unchanged
    assert_equal 'nope', resolve_group_member('nope')
  end

  def test_resolves_to_the_first_wanted_member
    group_with('completed', 'completed', nil, nil)
    assert_equal 'y3', resolve_group_member('yakuza')
  end

  # The rule that keeps a group's derived status and the member it names in agreement:
  # a member already in progress outranks an earlier untouched one.
  def test_prefers_a_member_in_progress_over_an_earlier_wanted_one
    group_with(nil, 'doing')
    assert_equal 'y2', resolve_group_member('yakuza')
  end

  def test_takes_the_first_member_in_progress_when_several_are
    group_with('doing', 'doing')
    assert_equal 'y1', resolve_group_member('yakuza')
  end

  def test_skips_retired_members_to_reach_a_later_live_one
    group_with('completed', 'retired', 'want-to')
    assert_equal 'y3', resolve_group_member('yakuza')
  end

  # on-hold is a deliberate pause, so it is never what you would pick up.
  def test_skips_a_paused_member
    group_with('on-hold', 'want-to')
    assert_equal 'y2', resolve_group_member('yakuza')
  end

  def test_raises_when_every_member_is_finished
    group_with('completed', 'retired')
    error = assert_raises(ListError::BadRequest) { resolve_group_member('yakuza') }
    assert_match(/no member left to do/, error.message)
  end

  def test_raises_when_the_only_survivor_is_paused
    group_with('completed', 'on-hold')
    assert_raises(ListError::BadRequest) { resolve_group_member('yakuza') }
  end

  # The schema type-refs `group`, so a member id that never existed cannot be saved in
  # the first place. The reachable version is a member deleted AFTER the group was
  # saved, which must not be mistaken for "nothing left to do".
  def test_ignores_a_member_deleted_out_from_under_the_group
    group_with('completed', nil)
    Item.get('y2').delete!
    error = assert_raises(ListError::BadRequest) { resolve_group_member('yakuza') }
    assert_match(/no member left to do/, error.message)
  end

  def test_still_resolves_when_a_deleted_member_sits_before_a_live_one
    group_with(nil, nil)
    Item.get('y1').delete!
    assert_equal 'y2', resolve_group_member('yakuza')
  end

end
