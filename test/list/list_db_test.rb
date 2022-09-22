require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/list/list'
require_relative '../helpers/test_list_db'

class ListDbTest < Minitest::Test

  def setup
    List.set_db_class(TestListDb)
  end

  def teardown
    TestListDb.teardown
  end

  ## Integration Tests

  def test_list_createGet
    TestListDb.save(List.new({"id" => "15", "name" => "Fifteen"}))
    item = TestListDb.get("15")
    assert_equal "15", item.id
    assert_equal "Fifteen", item.name
  end

  def test_list_createUpdateGet
    TestListDb.save(List.new({"id" => "1", "name" => "One"}))
    TestListDb.save(List.new({"id" => "1", "name" => "Uno"}))
    item = TestListDb.get("1")
    assert_equal "1", item.id
    assert_equal "Uno", item.name
    assert_equal 1, TestListDb.list().size
  end

  def test_list_createListDeleteList
    TestListDb.save(List.new({"id" => "3", "name" => "Three"}))
    items = TestListDb.list()
    assert_equal "3", items[0].id
    assert_equal "Three", items[0].name
    TestListDb.delete("3")
    assert_equal 0, TestListDb.list().size
  end

  def test_list_listEmpty
    items = TestListDb.list()
    assert_equal 0, items.size
  end

  def test_list_getEmpty
    item = TestListDb.get("10")
    assert_nil item
  end

end