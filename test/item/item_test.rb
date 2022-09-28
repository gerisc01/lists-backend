require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/item/item'
require_relative '../../src/item/item_db'

class ItemTest < Minitest::Test

  def setup
  end

  def teardown
  end

  ## Item generate keys (generic test)

  def test_item_keysAsMethods_success
    item = Item.new
    assert item.methods.include?(:id)
    assert item.methods.include?(:id=)
    assert item.methods.include?(:name)
    assert item.methods.include?(:name=)
  end

  ## Item initalize (generic test)

  def test_item_init_emptyParam
    item = Item.new
    assert !item.id.nil?
  end

  def test_item_init_jsonSuccess
    item = Item.new({"id" => "1", "name" => "One"})
    assert_equal "1", item.id
    assert_equal "One", item.name
  end

  def test_item_init_jsonUnknownKeys
    item = Item.new({"id" => "1", "name" => "One", "unknown" => "value"})
    assert_equal "1", item.id
    assert_equal "One", item.name
    assert !item.methods.include?("unknown")
  end

  ## Item validate (generic test)

  def test_item_validate_success
    item = Item.new({"id" => "1", "name" => "Name"})
    item.validate
  end

  def test_item_validate_expectedFail
    # No Id
    item = Item.new
    item.id = nil
    assert_raises do
      item.validate
    end
    # No Name
    item = Item.new({"id" => "1"})
    assert_raises do
      item.validate
    end
  end

  ## Item to/from object (generic test)

  def test_item_json_successfulLoad
    json = {"id" => "15", "name" => "Fifteen"}
    item = Item.from_object(json)
    assert_equal "15", item.id
    assert_equal "Fifteen", item.name
  end

  def test_item_json_successfulOutput
    item = Item.new
    item.id = "10"
    item.name = "Ten"
    json = item.to_object
    assert_equal "10", json["id"]
    assert_equal "Ten", json["name"]
  end

  ## Item CRUD

  def test_item_update_success
    item = Item.new({"name" => "An Item"})
    item.stubs(:validate).returns(nil).once
    ItemDb.stubs(:save).returns(nil).once
    item.save!
  end

  def test_item_create_success
    item = Item.new({"name" => "An Item"})
    item.stubs(:validate).returns(nil).once
    ItemDb.stubs(:save).returns(nil).once
    item.save!
  end

  def test_item_get_success
    ItemDb.stubs(:get).with("10").returns(Item.new({"id" => "10", "name" => "Ten"})).once
    item = Item.get("10")
    assert_equal "10", item.id
    assert_equal "Ten", item.name
  end

  def test_item_delete_success
    ItemDb.stubs(:delete).with("10").returns(nil).once
    item = Item.new({"id" => "10"})
    item.delete!
  end

  def test_item_delete_failure
    item = Item.new
    item.id = nil
    assert_raises do
      item.delete!
    end
  end

end