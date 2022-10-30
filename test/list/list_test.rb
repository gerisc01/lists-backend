require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/list/list'
require_relative '../../src/list/list_db'

class ListTest < Minitest::Test

  def setup
  end

  def teardown
  end

  ## List generate keys (generic test)

  def test_list_keysAsMethods_success
    list = List.new
    assert list.methods.include?(:id)
    assert list.methods.include?(:id=)
    assert list.methods.include?(:name)
    assert list.methods.include?(:name=)
    assert list.methods.include?(:items)
    assert list.methods.include?(:items=)
  end

  ## List initalize (generic test)

  def test_list_init_emptyParam
    list = List.new
    assert !list.id.nil?
  end

  def test_list_init_jsonSuccess
    list = List.new({"id" => "1", "name" => "One"})
    assert_equal "1", list.id
    assert_equal "One", list.name
  end

  def test_list_init_jsonUnknownKeys
    list = List.new({"id" => "1", "name" => "One", "unknown" => "value"})
    assert_equal "1", list.id
    assert_equal "One", list.name
    assert !list.methods.include?("unknown")
  end

  ## List validate

  def test_list_validate_success
    list = List.new({"id" => "1", "name" => "Name"})
    list.validate
  end

  def test_list_validate_expectedFail
    # No Id
    list = List.new
    list.id = nil
    assert_raises do
      list.validate
    end
    # No Name
    list = List.new({"id" => "1"})
    assert_raises do
      list.validate
    end
  end

  ## List to/from object

  def test_list_json_successfulLoad
    json = {"id" => "15", "name" => "Fifteen"}
    list = List.from_object(json)
    assert_equal "15", list.id
    assert_equal "Fifteen", list.name
  end

  def test_list_json_successfulOutput
    list = List.new
    list.id = "10"
    list.name = "Ten"
    json = list.to_object
    assert_equal "10", json["id"]
    assert_equal "Ten", json["name"]
  end

  ## List CRUD

  def test_list_update_success
    list = List.new({"name" => "A List"})
    list.stubs(:validate).returns(nil).once
    ListDb.stubs(:save).returns(nil).once
    list.save!
  end

  def test_list_create_success
    list = List.new({"name" => "A List"})
    list.stubs(:validate).returns(nil).once
    ListDb.stubs(:save).returns(nil).once
    list.save!
  end

  def test_list_get_success
    ListDb.stubs(:get).with("10").returns(List.new({"id" => "10", "name" => "Ten"})).once
    list = List.get("10")
    assert_equal "10", list.id
    assert_equal "Ten", list.name
  end

  def test_list_list_success
    ListDb.stubs(:list).returns([List.new, List.new]).once
    lists = List.list
    assert lists.is_a? Array
    assert_equal 2, lists.size
  end

  def test_list_delete_success
    ListDb.stubs(:delete).with("10").returns(nil).once
    list = List.new({"id" => "10"})
    list.delete!
  end

  def test_list_delete_failure
    list = List.new
    list.id = nil
    assert_raises do
      list.delete!
    end
  end

  ## List Items

  def test_list_add_item_invalid_list
    list = List.new
    list.items = nil
    assert_raises do
      list.validate
    end
    list.items = ""
    assert_raises do
      list.validate
    end
  end

  def test_list_add_item_success
    # Stub and assert list is empty
    list = List.new
    Item.stubs(:exist?).with("1").returns(true).once
    Item.stubs(:exist?).with("2").returns(true).once
    assert_equal 0, list.items.size
    # Add 1 item to the list and make sure it was added
    item1 = Item.new({"id" => "1", "name" => "One"})
    list.add_item(item1)
    assert_equal 1, list.items.size
    # Add another item to the list and make sure it's added to the end
    item2 = Item.new({"id" => "2", "name" => "Two"})
    list.add_item(item2)
    assert_equal 2, list.items.size
    assert_equal "1", list.items[0]
    assert_equal "2", list.items[1]
  end

  def test_list_add_item_new_item
    Item.stubs(:exist?).with("1").returns(false).once
    list = List.new
    item = Item.new({"id" => "1", "name" => "One"})
    item.stubs(:save!).once
    list.add_item(item)
    assert_equal 1, list.items.size
  end

  def test_list_remove_item_success
    list = List.new
    list.items = ["1", "2"]
    item = Item.new({"id" => "1", "name" => "One"})
    list.remove_item(item)
    assert_equal 1, list.items.size
    assert_equal "2", list.items[0]
  end

  def test_list_remove_item_with_id_success
    list = List.new
    list.items = ["1", "2"]
    list.remove_item("2")
    assert_equal 1, list.items.size
    assert_equal "1", list.items[0]
  end

  def test_list_remove_item_successfully_ignored
    list = List.new
    list.items = ["1", "2"]
    item = Item.new({"id" => "3", "name" => "Three"})
    list.remove_item(item)
    assert_equal 2, list.items.size
  end

  ## List Templates

  def test_list_add_template
    list = List.new
    list.set_template('aKey')
    assert_equal 'aKey', list.template
  end

  def test_list_remove_template
    list = List.new
    list.template = 'aKey'
    list.remove_template
    assert_nil list.template
  end

end