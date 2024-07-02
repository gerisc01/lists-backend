require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/actions/copy_item'

class CopyItemTest < MinitestWrapper

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @group = ItemGroup.new({'id' => 'one', 'name' => 'Group', 'group' => [@item.id]})
    @list = List.new({'id' => 'a', 'name' => 'list-one', 'items' => [@item.id]})
    @list_empty = List.new({'id' => 'c', 'name' => 'list-empty'})
    [ @item, @group, @list, @list_empty ].each { |obj| obj.save! }
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_copy_item_to_empty_list
    copy_item(@item.id, @list_empty.id)
    assert_equal [@item.id], @list.items
    assert_equal [@item.id], @list_empty.items
  end

  def test_copy_group_item
    copy_item(@group.id, @list.id)
    assert_equal [@item.id, @group.id], @list.items
  end

  def test_copy_item_not_found_failure
    assert_raises(ListError::BadRequest) { copy_item('NOT_FOUND', @list.id) }
    assert_raises(ListError::BadRequest) { copy_item(@item.id, 'NOT_FOUND') }
  end

end