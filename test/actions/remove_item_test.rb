require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/actions/remove_item'

class RemoveItemTest < MinitestWrapper

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    @group = ItemGroup.new({'id' => 'one', 'name' => 'Group', 'group' => [@item2.id]})
    @list = List.new({'id' => 'a', 'name' => 'list-one', 'items' => [@item.id, @group.id, @item.id, @item2.id]})
    @list_empty = List.new({'id' => 'c', 'name' => 'list-empty'})
    [ @item, @item2, @group, @list, @list_empty ].each { |obj| obj.save! }
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_remove_multiple_items
    remove_item(@item.id, @list.id)
    assert_equal [@group.id, @item2.id], @list.items
  end

  def test_remove_item_with_index
    remove_item(@item.id, @list.id, 2)
    assert_equal [@item.id, @group.id, @item2.id], @list.items
  end

  def test_remove_group_item
    remove_item(@group.id, @list.id)
    assert_equal [@item.id, @item.id, @item2.id], @list.items
  end

  def test_remove_item_empty_list
    assert_raises(ListError::BadRequest) { remove_item('1', @list_empty.id) }
  end

  def test_remove_item_not_found_item
    assert_raises(ListError::BadRequest) { remove_item('NOT_FOUND', @list.id) }
  end

  def test_remove_item_not_found_list_failure
    assert_raises(ListError::BadRequest) { remove_item(@item.id, 'NOT_FOUND') }
  end

  def test_remove_item_not_found_index
    assert_raises(ListError::BadRequest) { remove_item(@item.id, @list.id, 10) }
    assert_raises(ListError::BadRequest) { remove_item('NOT_FOUND', @list.id, 10) }
  end

end