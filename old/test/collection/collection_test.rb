require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/type/template'
require_relative '../../src/type/collection'
require_relative '../../src/db/collection_db'

class CollectionTest < Minitest::Test

  def setup
  end

  def teardown
  end

  ## Collection generate keys (generic test)

  def test_collection_keysAsMethods_success
    collection = Collection.new
    assert collection.methods.include?(:id)
    assert collection.methods.include?(:id=)
    assert collection.methods.include?(:key)
    assert collection.methods.include?(:key=)
    assert collection.methods.include?(:name)
    assert collection.methods.include?(:name=)
    assert collection.methods.include?(:lists)
    assert collection.methods.include?(:lists=)
  end

  ## Collection initalize (generic test)

  def test_collection_init_emptyParam
    collection = Collection.new
    assert !collection.id.nil?
  end

  def test_collection_init_jsonSuccess
    collection = Collection.new({"id" => "1", "key" => "one", "name" => "One"})
    assert_equal "1", collection.id
    assert_equal "one", collection.key
    assert_equal "One", collection.name
  end

  def test_collection_init_jsonUnknownKeys
    collection = Collection.new({"id" => "1", "name" => "One", "unknown" => "value"})
    assert_equal "1", collection.id
    assert_equal "One", collection.name
    assert !collection.methods.include?("unknown")
  end

  ## Collection validate

  def test_collection_validate_success
    collection = Collection.new({"id" => "1", "key" => "a-key", "name" => "Name"})
    collection.validate
  end

  def test_collection_validate_expectedFail
    # No Id
    collection = Collection.new
    collection.id = nil
    assert_raises do
      collection.validate
    end
    # No Name
    collection = Collection.new({"id" => "1"})
    assert_raises do
      collection.validate
    end
  end

  ## Collection to/from object

  def test_collection_json_successfulLoad
    json = {
      "id" => "15",
      "key" => "fifteen",
      "name" => "Fifteen",
      "lists" => ["1"],
      "templates" => {
        "test" => {
          "key" => "test",
          "fields" => {"name" => "string", "replay" => "boolean"}
        }
      }
    }
    collection = Collection.from_object(json)
    assert_equal "15", collection.id
    assert_equal "fifteen", collection.key
    assert_equal "Fifteen", collection.name
    assert_equal "1", collection.lists[0]
    assert_equal 1, collection.templates.size
    assert_equal "boolean", collection.templates["test"]["fields"]["replay"]
  end

  def test_collection_json_successfulOutput
    collection = Collection.new
    collection.id = "10"
    collection.key = "ten"
    collection.name = "Ten"
    collection.lists = ["2", "3"]
    json = collection.to_object
    assert_equal "10", json["id"]
    assert_equal "ten", json["key"]
    assert_equal "Ten", json["name"]
    assert_equal "2", json["lists"][0]
    assert_equal "3", json["lists"][1]
  end

  ## Collection CRUD

  def test_collection_update_success
    collection = Collection.new({"name" => "A Collection"})
    collection.stubs(:validate).returns(nil).once
    CollectionDb.stubs(:save).returns(nil).once
    collection.save!
  end

  def test_collection_create_success
    collection = Collection.new({"name" => "A Collection"})
    collection.stubs(:validate).returns(nil).once
    CollectionDb.stubs(:save).returns(nil).once
    collection.save!
  end

  def test_collection_get_success
    CollectionDb.stubs(:get).with("10").returns(Collection.new({"id" => "10", "name" => "Ten"})).once
    collection = Collection.get("10")
    assert_equal "10", collection.id
    assert_equal "Ten", collection.name
  end

  def test_collection_list_success
    CollectionDb.stubs(:list).returns([Collection.new, Collection.new]).once
    collections = Collection.list
    assert collections.is_a? Array
    assert_equal 2, collections.size
  end

  def test_collection_delete_success
    CollectionDb.stubs(:delete).with("10").returns(nil).once
    collection = Collection.new({"id" => "10"})
    collection.delete!
  end

  def test_collection_delete_failure
    collection = Collection.new
    collection.id = nil
    assert_raises do
      collection.delete!
    end
  end

  ## Collection Add Template
  def test_collection_add_template
    template = Template.new({"id" => "test", "key" => "test", "fields" => {"name" => "string", "replay" => "boolean"}})
    collection = Collection.new
    collection.add_template(template)
    assert_equal 1, collection.templates.size
    assert_equal "test", collection.templates["test"].key
  end

  def test_collection_remove_template
    collection = Collection.new({"templates" => {"test" => {"key" => "test", "fields" => {}}}})
    assert_equal 1, collection.templates.size
    collection.remove_template("test")
    assert_equal 0, collection.templates.size
    collection.remove_template("empty")
    assert_equal 0, collection.templates.size
  end

  ## Collection Add List

  def test_collection_add_list_invalid_collection
    collection = Collection.new
    collection.lists = nil
    assert_raises do
      collection.validate
    end
    collection.lists = ""
    assert_raises do
      collection.validate
    end
  end

  def test_collection_add_list_success
    # Stub and assert collection is empty
    collection = Collection.new
    List.stubs(:exist?).with("1").returns(true).once
    List.stubs(:exist?).with("2").returns(true).once
    assert_equal 0, collection.lists.size
    # Add 1 list to the collection and make sure it was added
    list1 = List.new({"id" => "1", "name" => "One"})
    collection.add_list(list1)
    assert_equal 1, collection.lists.size
    # Add another list to the collection and make sure it's added to the end
    list2 = List.new({"id" => "2", "name" => "Two"})
    collection.add_list(list2)
    assert_equal 2, collection.lists.size
    assert_equal "1", collection.lists[0]
    assert_equal "2", collection.lists[1]
  end

  def test_collection_add_list_new_list
    List.stubs(:exist?).with("1").returns(false).once
    collection = Collection.new
    list = List.new({"id" => "1", "name" => "One", "items" => []})
    list.stubs(:save!).once
    collection.add_list(list)
    assert_equal 1, collection.lists.size
  end

  def test_collection_remove_list_success
    collection = Collection.new
    collection.lists = ["1", "2"]
    list = List.new({"id" => "1", "name" => "One"})
    collection.remove_list(list)
    assert_equal 1, collection.lists.size
    assert_equal "2", collection.lists[0]
  end

  def test_collection_remove_list_with_id_success
    collection = Collection.new
    collection.lists = ["1", "2"]
    collection.remove_list("2")
    assert_equal 1, collection.lists.size
    assert_equal "1", collection.lists[0]
  end

  def test_collection_remove_list_successfully_ignored
    collection = Collection.new
    collection.lists = ["1", "2"]
    list = List.new({"id" => "3", "name" => "Three"})
    collection.remove_list(list)
    assert_equal 2, collection.lists.size
  end

end