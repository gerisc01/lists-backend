require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/actions/promote_group_item'

class PromoteGroupItemTest < MinitestWrapper

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    @item3 = Item.new({'id' => '3', 'name' => 'Three'})
    @group = ItemGroup.new({'id' => 'one', 'name' => 'Group 1', 'group' => [@item.id]})
    @group2 = ItemGroup.new({'id' => 'two', 'name' => 'Group 2', 'group' => [@item.id, @item2.id]})
    @group3 = ItemGroup.new({'id' => 'three', 'name' => 'Group 3', 'group' => [@item.id, @item2.id, @item3.id]})
    @list = List.new({'id' => 'a', 'name' => 'list-one', 'items' => [@group.id, @group2.id, @group3.id]})
    @list_empty = List.new({'id' => 'empty', 'name' => 'list-empty'})
    [ @item, @item2, @item3, @group, @group2, @group3, @list, @list_empty ].each { |obj| obj.save! }
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_promote_group_item_single_item
    promote_group_item(@group.id, @item.id, @list.id)
    assert_equal [@group2.id, @group3.id, @item.id], @list.items
  end

  def test_promote_group_item_two_items
    promote_group_item(@group2.id, @item.id, @list.id)
    assert_equal [@group.id, @item2.id, @group3.id, @item.id], @list.items
  end

  def test_promote_group_item_three_plus_items
    promote_group_item(@group3.id, @item2.id, @list.id)
    assert_equal [@group.id, @group2.id, @group3.id, @item2.id], @list.items
    assert_equal [@item.id, @item3.id], @group3.group
  end

  def test_promote_group_item_not_found_failures
    assert_raises(ListError::BadRequest) { promote_group_item('NOT_FOUND', @item.id, @list.id) }
    assert_raises(ListError::BadRequest) { promote_group_item(@group.id, 'NOT_FOUND', @list.id) }
    assert_raises(ListError::BadRequest) { promote_group_item(@group.id, @item.id, 'NOT_FOUND') }
  end

  def test_promote_group_item_not_in_list_failure
    assert_raises(ListError::BadRequest) { promote_group_item(@group.id, @item.id, @list_empty.id) }
  end

end