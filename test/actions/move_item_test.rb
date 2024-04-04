require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/actions/move_item'

class MoveItemTest < MinitestWrapper

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    @group = ItemGroup.new({'id' => 'one', 'name' => 'Group', 'group' => [@item2.id]})
    @list = List.new({'id' => 'a', 'name' => 'list-one', 'items' => [@item.id, @group.id]})
    @list2 = List.new({'id' => 'b', 'name' => 'list-two', 'items' => [@item2.id]})
    @list_empty = List.new({'id' => 'c', 'name' => 'list-empty'})
    [ @item, @item2, @group, @list, @list2, @list_empty ].each { |obj| obj.save! }
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_move_item_to_empty_list
    move_item(@item.id, @list.id, @list_empty.id)
    assert_equal [@group.id], @list.items
    assert_equal [@item.id], @list_empty.items
  end

  def test_move_item_from_single_item_list
    move_item(@item2.id, @list2.id, @list.id)
    assert_equal [], @list2.items
    assert_equal [@item.id, @group.id, @item2.id], @list.items
  end

  def test_move_group_item
    move_item(@group.id, @list.id, @list2.id)
    assert_equal [@item.id], @list.items
    assert_equal [@item2.id, @group.id], @list2.items
  end

  def test_move_item_not_found_failure
    assert_raises(ListError::BadRequest) { move_item('NOT_FOUND', @list.id, @list2.id) }
    assert_raises(ListError::BadRequest) { move_item(@item.id, 'NOT_FOUND', @list2.id) }
    assert_raises(ListError::BadRequest) { move_item(@item.id, @list.id, 'NOT_FOUND') }
  end

  def test_move_item_not_on_from_list_failure
    assert_raises(ListError::BadRequest) { move_item(@item.id, @list2.id, @list.id) }
  end

end