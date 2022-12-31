require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/schema/schema'
require_relative '../../src/type/template'

class SchemaTypesTest < Minitest::Test

  class RefObj
    attr_accessor :id
  end

  class TypeTestClass
    attr_accessor :json

    @@schema = Schema.new
    @@schema.key = "test-schema"
    @@schema.display_name = "Test Schema"
    @@schema.fields = {
      "key" => {:required => false, :type => String, :display_name => 'Key'},
      "length" => {:required => false, :type => Integer, :display_name => 'Length'},
      "finished" => {:required => false, :type => SchemaType::Date, :display_name => 'Finished'},
      "replay" => {:required => false, :type => SchemaType::Boolean, :display_name => 'Replay'},
      "ingredients" => {:required => false, :type => Array, :subtype => String, :display_name => 'Ingredients'},
      "ref_objs" => {:required => false, :type => Array, :subtype => RefObj, :type_ref => true, :display_name => 'Ref Objs'},
      "templates" => {:required => false, :type => Hash, :subtype => String, :display_name => 'Templates'}
    }
    @@schema.apply_schema(self)

    def initialize(json = nil)
      @json = json.nil? ? {} : json
    end

    def self.get_schema
      return @@schema
    end
  end

  def setup
  end

  def teardown
  end

  ## Test standard types

  def test_schema_string
    gc = TypeTestClass.new({"key" => "12345"})
    TypeTestClass.get_schema.validate(gc)
    gc = TypeTestClass.new({"key" => 12345})
    assert_raises(ValidationError) do
      TypeTestClass.get_schema.validate(gc)
    end
  end

  def test_schema_integer
    gc = TypeTestClass.new({"length" => 12345})
    TypeTestClass.get_schema.validate(gc)
    gc = TypeTestClass.new({"length" => "12345"})
    assert_raises(ValidationError) do
      TypeTestClass.get_schema.validate(gc)
    end
  end

  def test_schema_boolean
    gc = TypeTestClass.new({"replay" => true})
    TypeTestClass.get_schema.validate(gc)
    gc = TypeTestClass.new({"replay" => false})
    TypeTestClass.get_schema.validate(gc)
    gc = TypeTestClass.new({"replay" => "true"})
    assert_raises(ValidationError) do
      TypeTestClass.get_schema.validate(gc)
    end
  end

  def test_schema_date
    gc = TypeTestClass.new({"finished" => "2022-05-19"})
    TypeTestClass.get_schema.validate(gc)
    gc = TypeTestClass.new({"finished" => Date.new(2022, 5, 19)})
    TypeTestClass.get_schema.validate(gc)
    gc = TypeTestClass.new({"finished" => 15})
    assert_raises(ValidationError) do
      TypeTestClass.get_schema.validate(gc)
    end
  end

  ## Test array types

  def test_schema_array_string
    gc = TypeTestClass.new({"ingredients" => ["1", "2", "3"]})
    TypeTestClass.get_schema.validate(gc)
    gc = TypeTestClass.new({"ingredients" => ["1", "2", "3", 4]})
    assert_raises(ValidationError) do
      TypeTestClass.get_schema.validate(gc)
    end
  end

  def test_schema_array_string_empty
    gc = TypeTestClass.new({"ingredients" => []})
    TypeTestClass.get_schema.validate(gc)
  end

  ## Test Add Collection
  def test_schema_array_add_element
    gc = TypeTestClass.new()
    # Add to a null collection
    gc.add_ingredient("1 onion")
    assert_equal "1 onion", gc.ingredients[0]
    # Add to an existing collection
    gc.add_ingredient("2 cloves garlic")
    assert_equal "2 cloves garlic", gc.ingredients[1]
    gc = TypeTestClass.new()
    assert_raises(ValidationError) do
      gc.add_ingredient(1)
    end
  end

  def test_schema_array_add_type_ref
    RefObj.stubs(:exist?).with("12345").returns(true).once
    RefObj.stubs(:exist?).with("54321").returns(true).once
    gc = TypeTestClass.new()
    # Successfully add RefObj
    obj = RefObj.new
    obj.id = "12345"
    gc.add_ref_obj(obj)
    assert_equal "12345", gc.ref_objs[0]
    # Successfully add RefObj id
    gc.add_ref_obj("54321")
    assert_equal "54321", gc.ref_objs[1]
    # Failed to add RefObj id
    assert_raises(ValidationError) do
      gc.add_ref_obj(54321)
    end
  end

  def test_schema_array_remove_element
    # Ignore removing an item when an array is null
    gc = TypeTestClass.new()
    gc.remove_ingredient("32 oz penne pasta")
    # Remove an item that is present
    gc = TypeTestClass.new({"ingredients" => ["1 onion"]})
    gc.remove_ingredient("1 onion")
    # Ignore removing an item that doesn't exist
    gc = TypeTestClass.new({"ingredients" => ["1 onion"]})
    gc.remove_ingredient("32 oz penne pasta")
  end

  def test_schema_array_remove_type_ref
    gc = TypeTestClass.new()
    gc.ref_objs = ["12345", "54321"]
    # Successfully add RefObj
    obj = RefObj.new
    obj.id = "12345"
    gc.remove_ref_obj(obj)
    assert_nil gc.ref_objs.find { |id| id == "12345" } 
    gc.remove_ref_obj("54321")
    assert_nil gc.ref_objs.find { |id| id == "54321" }
    assert_equal 0,  gc.ref_objs.size
  end

  ## Test hash types

  def test_schema_hash_string
    gc = TypeTestClass.new({"templates" => {"1" => "One", "2" => "Two"}})
    TypeTestClass.get_schema.validate(gc)
    gc = TypeTestClass.new({"templates" => {"1" => "One", "2" => "Two", "3" => 3}})
    assert_raises(ValidationError) do
      TypeTestClass.get_schema.validate(gc)
    end
  end

  def test_schema_hash_string_empty
    gc = TypeTestClass.new({"templates" => {}})
    TypeTestClass.get_schema.validate(gc)
  end

end