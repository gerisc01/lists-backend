require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/item/item'
require_relative '../helpers/test_item_db'

class ItemDbTest < Minitest::Test

  def setup
    Item.set_db_class(TestItemDb)
  end

  def teardown
    TestItemDb.teardown
  end

  ## Integration Tests

  def test_item_createGet
    TestItemDb.save(Item.new({"id" => "15", "name" => "Fifteen"}))
    item = TestItemDb.get("15")
    assert_equal "15", item.id
    assert_equal "Fifteen", item.name
  end

  def test_item_createUpdateGet
    TestItemDb.save(Item.new({"id" => "1", "name" => "One"}))
    TestItemDb.save(Item.new({"id" => "1", "name" => "Uno"}))
    item = TestItemDb.get("1")
    assert_equal "1", item.id
    assert_equal "Uno", item.name
    assert_equal 1, TestItemDb.list().size
  end

  def test_item_createListDeleteList
    TestItemDb.save(Item.new({"id" => "3", "name" => "Three"}))
    items = TestItemDb.list()
    assert_equal "3", items[0].id
    assert_equal "Three", items[0].name
    TestItemDb.delete("3")
    assert_equal 0, TestItemDb.list().size
  end

  def test_item_listEmpty
    items = TestItemDb.list()
    assert_equal 0, items.size
  end

  def test_item_getEmpty
    item = TestItemDb.get("10")
    assert_nil item
  end

end