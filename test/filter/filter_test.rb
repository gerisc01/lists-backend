require_relative '../minitest_wrapper'
require_relative '../../src/type/collection'
require_relative '../../src/filter/filter'

class FilterTest < MinitestWrapper

  def setup
    collection = {
      'id' => '1', 'name' => 'Un', 'lists' => ['1', '2', '3']
    }
    Collection.stubs(:get).with('1').returns(Collection.new(collection)).once
    lists = [
      {'id' => '1', 'name' => 'First', 'items' => ['1', '2']},
      {'id' => '2', 'name' => 'Second'},
      {'id' => '3', 'name' => 'Third', 'items' => ['2', '3']}
    ]
    List.stubs(:get).with('1').returns(List.new(lists[0])).once
    List.stubs(:get).with('2').returns(List.new(lists[1])).once
    List.stubs(:get).with('3').returns(List.new(lists[2])).once
    items = [
      {'id' => '1', 'name' => 'Uno'},
      {'id' => '2', 'name' => 'Dos'},
      {'id' => '3', 'name' => 'Tres'},
      {'id' => '4', 'name' => 'Quattro'}
    ]
    Item.stubs(:get).with('1').returns(Item.new(items[0])).once
    Item.stubs(:get).with('2').returns(Item.new(items[1])).twice
    Item.stubs(:get).with('3').returns(Item.new(items[2])).once
    Item.stubs(:get).with('4').returns(Item.new(items[3])).never
  end

  def teardown
    mocha_teardown
  end

  def test_filter_empty
    matching_ids = Filter.find_matching_items('1', "list.name = Second")
    assert_equal 0, matching_ids.size
  end

  def test_filter_basic
    matching_ids = Filter.find_matching_items('1', "list.name = First")
    assert_equal 2, matching_ids.size
    assert matching_ids.include?('1')
    assert matching_ids.include?('2')
  end

  def test_filter_basic_paren_or
    matching_ids = Filter.find_matching_items('1', "list.name = (First OR Second)")
    assert_equal 2, matching_ids.size
    assert matching_ids.include?('1')
    assert matching_ids.include?('2')
  end

  def test_filter_parent_or_combo
    matching_ids = Filter.find_matching_items('1', "list.name = (First OR Second) OR list.name = Third")
    assert_equal 3, matching_ids.size
    assert matching_ids.include?('1')
    assert matching_ids.include?('2')
    assert matching_ids.include?('3')
  end

  def test_filter_basic_and
    matching_ids = Filter.find_matching_items('1', "list.name = First AND list.name = Third")
    assert_equal 1, matching_ids.size
    assert matching_ids.include?('2')
  end

  def test_filter_empty_start_or
    matching_ids = Filter.find_matching_items('1', "list.name = Bad1 OR list.name = Bad2 OR list.name = First")
    assert_equal 2, matching_ids.size
    assert matching_ids.include?('1')
    assert matching_ids.include?('2')
  end

  def test_filter_empty_start_and
    matching_ids = Filter.find_matching_items('1', "list.name = Second AND list.name = Third")
    assert_equal 0, matching_ids.size
  end

end