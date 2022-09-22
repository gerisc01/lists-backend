require 'minitest/autorun'
require 'mocha/minitest'
require '../src/list/list'
require '../src/list/list_db'

class ListTest < Minitest::Test

  def setup
  end

  def teardown
  end

  ## List generate keys

  def test_list_keysAsMethods_success
    list = List.new
    assert list.methods.include?(:id)
    assert list.methods.include?(:id=)
    assert list.methods.include?(:name)
    assert list.methods.include?(:name=)
  end

  ## List initalize

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

end