require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/type/collection'
require_relative '../helpers/test_collection_db'

class CollectionDbTest < Minitest::Test

  def setup
    Collection.set_db_class(TestCollectionDb)
  end

  def teardown
    TestCollectionDb.teardown
  end

  ## Integration Tests

  def test_collection_createGet
    TestCollectionDb.save(Collection.new({"id" => "15", "key" => "fifteen", "name" => "Fifteen"}))
    collection = TestCollectionDb.get("15")
    assert_equal "15", collection.id
    assert_equal "Fifteen", collection.name
  end

  def test_collection_createUpdateGet
    TestCollectionDb.save(Collection.new({"id" => "1", "key" => "one", "name" => "One"}))
    TestCollectionDb.save(Collection.new({"id" => "1", "key" => "uno", "name" => "Uno"}))
    collection = TestCollectionDb.get("1")
    assert_equal "1", collection.id
    assert_equal "Uno", collection.name
    assert_equal 1, TestCollectionDb.list().size
  end

  def test_collection_createListDeleteList
    TestCollectionDb.save(Collection.new({"id" => "3", "key" => "three", "name" => "Three"}))
    collections = TestCollectionDb.list()
    assert_equal "3", collections[0].id
    assert_equal "Three", collections[0].name
    TestCollectionDb.delete("3")
    assert_equal 0, TestCollectionDb.list().size
  end

  def test_collection_listEmpty
    collections = TestCollectionDb.list()
    assert_equal 0, collections.size
  end

  def test_collection_getEmpty
    collection = TestCollectionDb.get("10")
    assert_nil collection
  end

end