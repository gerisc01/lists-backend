require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/collection'
require_relative '../../src/type/list'
require_relative '../../src/type/placement'
require_relative '../../src/type/template'
require_relative '../../src/actions/auto_archive'
require_relative '../../src/actions/delete_placement'
require_relative '../../src/actions/reconcile'

# A group member's shelf home is its GROUP's. Only the group id sits in `list.items`, so
# a bare id check reads every member as list-free — which made a member behave like a
# board-born one-off at four separate doors. These pin all four, because each has a
# different and progressively worse consequence.
class GroupMemberShelfHomeTest < MinitestWrapper

  AS_OF = '2026-07-27'   # a Monday — monday_of(AS_OF) == AS_OF
  PAST  = '2026-07-20'   # the prior Monday — a week that is over

  def setup
    Collection.new({'id' => 'c1', 'name' => 'C'}).save!
    %w[s1 s2].each { |id| Item.new({'id' => id, 'name' => id}).save! }
    Item.new({'id' => 'loose', 'name' => 'loose'}).save!
    ItemGroup.new({'id' => 'g1', 'name' => 'Pegboard', 'group' => %w[s1 s2]}).save!
    # The list holds the GROUP, never its members — this is the shape the bug hid in.
    List.new({'id' => 'l1', 'name' => 'Shelf', 'items' => ['g1']}).save!
  end

  def teardown
    TypeStorage.clear_test_storage
  end

  def floating(item_id, overrides = {})
    Placement.new({
      'item_id' => item_id, 'collection_id' => 'c1', 'floating' => true,
    }.merge(overrides)).tap(&:validate).tap(&:save!)
  end

  def test_a_member_has_a_shelf_home_through_its_group
    assert item_has_shelf_home?('s1')
    assert item_has_shelf_home?('g1')
    refute item_has_shelf_home?('loose')
  end

  # Worst of the four: Remove on a staged member used to delete the member itself.
  def test_removing_a_members_last_placement_keeps_the_member
    p = floating('s1')
    delete_placement(p.id)

    refute_nil Item.get('s1')
    assert_equal %w[s1 s2], ItemGroup.get('g1').group
  end

  # A member left in the pile is RELEASED like any shelf item, not lapsed — lapsing would
  # mark a resolution on something that simply wasn't done, and then archive it.
  def test_a_stale_member_placement_is_released_not_lapsed
    p = floating('s1', 'staged_week' => PAST)

    result = reconcile(as_of_date: AS_OF)

    assert_equal [p.id], result['released']
    assert_empty result['lapsed']
    assert_nil Placement.get(p.id)
    assert_equal 'want-to', Item.get('s1').json['status']
  end

  # Archive is the ONE door where board-born behavior is right for a member: its placement
  # set is as finite and closed as a one-off's, so checking the box is the whole statement.
  def test_a_member_archives_once_every_placement_resolves
    p = floating('s1')
    p.resolution = 'completed'
    p.save!

    refute_nil maybe_auto_archive('s1', as_of_date: AS_OF)
    assert_equal 'completed', Item.get('s1').json['status']
  end

  def test_an_unplanned_member_does_not_archive
    assert_nil maybe_auto_archive('s1', as_of_date: AS_OF)
    assert_equal 'want-to', Item.get('s1').json['status']
  end

  def test_a_member_with_an_open_placement_does_not_archive
    floating('s1')
    p = floating('s1', 'date' => AS_OF, 'floating' => false)
    p.resolution = 'completed'
    p.save!

    assert_nil maybe_auto_archive('s1', as_of_date: AS_OF)
    assert_equal 'want-to', Item.get('s1').json['status']
  end

  # A member that DECLARED itself a multi-sitting thing ("this is a game") is a series of
  # runs by definition, so its placement set is not finite and close_instance owns its
  # ending. This is the line the whole rule is drawn on.
  def test_a_run_keeping_member_does_not_archive
    child = Template.new
    child.id = 'playthrough'
    child.key = 'playthrough'
    child.display_name = 'Playthrough'
    child.fields = [{ :key => 'name', :display_name => 'Name', :type => String, :required => true }]
    child.save!
    parent = Template.new
    parent.id = 'game'
    parent.key = 'game'
    parent.display_name = 'Game'
    parent.fields = [{ :key => 'name', :display_name => 'Name', :type => String, :required => true }]
    parent.attributes = { 'instances' => { 'template' => 'playthrough' } }
    parent.save!
    Item.get('s1').tap { |i| i.json['templates'] = ['game'] }.save!

    p = floating('s1')
    p.resolution = 'completed'
    p.save!

    assert_nil maybe_auto_archive('s1', as_of_date: AS_OF)
    assert_equal 'want-to', Item.get('s1').json['status']
  end

  # A member that ALSO holds a list row of its own is a shelf item in its own right, and
  # the shelf rule applies to it unchanged.
  def test_a_member_with_its_own_list_row_does_not_archive
    List.new({'id' => 'l2', 'name' => 'Shelf 2', 'items' => ['s2']}).save!
    p = floating('s2')
    p.resolution = 'completed'
    p.save!

    assert_nil maybe_auto_archive('s2', as_of_date: AS_OF)
    assert_equal 'want-to', Item.get('s2').json['status']
  end
end
