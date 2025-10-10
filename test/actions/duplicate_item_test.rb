require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/actions/duplicate_item'

class DuplicateItemTest < MinitestWrapper

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @list = List.new({'id' => 'a', 'name' => 'list-one', 'items' => [@item.id]})
    @list_empty = List.new({'id' => 'b', 'name' => 'list-empty'})
    [ @item, @list, @list_empty ].each { |obj| obj.save! }
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_duplicate_item_to_existing_list
    assert_equal [@item.id], @list.items
    new_item = duplicate_item(@item.id, @list.id)
    assert_equal [@item.id, new_item.id], @list.items
  end

  def test_duplicate_item_to_empty_list
    new_item = duplicate_item(@item.id, @list_empty.id)
    assert_equal [@item.id], @list.items
    assert_equal [new_item.id], @list_empty.items
  end

  def test_duplicate_item_to_no_list
    new_item = duplicate_item(@item.id, nil)
    assert_equal [@item.id], @list.items
    assert_nil @list_empty.items
    listed_items = Item.list
    assert_equal 2, listed_items.size
    assert_includes listed_items.map(&:id), new_item.id
  end

  def test_duplicate_item_not_found_failure
    assert_raises(ListError::BadRequest) { duplicate_item('NOT_FOUND', @list.id) }
    assert_raises(ListError::BadRequest) { duplicate_item(@item.id, 'NOT_FOUND') }
    assert_equal 1, Item.list.size
  end

end
