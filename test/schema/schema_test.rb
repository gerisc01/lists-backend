require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/schema/schema'
require_relative '../../src/type/template'

class SchemaTest < Minitest::Test

  class GenericClass
    attr_accessor :json

    @@schema = Schema.new
    @@schema.key = "collection"
    @@schema.display_name = "Collection"
    @@schema.fields = {
      "id" => {:required => true, :type => String, :display_name => 'Id'},
      "key" => {:required => true, :type => String, :display_name => 'Key'},
      "name" => {:required => true, :type => String, :display_name => 'Name'},
      "lists" => {:required => true, :type => Array, :display_name => 'Lists'},
      "templates" => {:required => false, :type => Hash, :display_name => 'Templates'}
    }
    @@schema.apply_schema(self)

    def initialize(json = nil)
      @json = json.nil? ? {} : json
      @json["id"] = SecureRandom.uuid if @json["id"].nil?
      @json["lists"] = [] if @json["lists"].nil?
    end

    def self.get_schema
      return @@schema
    end
  end

  def setup
  end

  def teardown
  end

  ## Schema generate keys (generic test)

  def test_schema_create_methods
    gc = GenericClass.new
    assert gc.methods.include?(:id)
    assert gc.methods.include?(:id=)
    assert gc.methods.include?(:key)
    assert gc.methods.include?(:key=)
    assert gc.methods.include?(:name)
    assert gc.methods.include?(:name=)
    assert gc.methods.include?(:lists)
    assert gc.methods.include?(:lists=)
    assert gc.methods.include?(:templates)
    assert gc.methods.include?(:templates=)
  end

  def test_schema_populate_schema
    # @schema.apply_schema(GenericClass)
    gc = GenericClass.new
    gc.id = "12345"
    gc.key = "collection"
    gc.lists = [1, 2, 3]
    gc.templates = {'one' => 'One', 'two' => 'Two'}

    assert_equal "12345", gc.id
    assert_equal "collection", gc.key
    assert_equal 3, gc.lists.size
    assert_equal 3, gc.lists[2]
    assert_equal 'Two', gc.templates['two']
  end

  def test_schema_multiple_instances
    gc1 = GenericClass.new
    gc1.id = "1"

    gc2 = GenericClass.new
    gc2.id = "2"

    assert_equal "1", gc1.id
    assert_equal "2", gc2.id
  end

  ## Schema validate

  def test_schema_validate_no_errors
    gc = GenericClass.new({"id" => "1", "key" => "collection", "name" => "Collection", "lists" => ["1"]})
    GenericClass.get_schema.validate(gc)
  end

  def test_schema_validate_required
    # Missing a required value raises an error
    gc = GenericClass.new({"id" => "1", "key" => "collection", "name" => "Collection"})
    assert_raises(ValidationError) do
      GenericClass.get_schema.validate(gc)
    end
    # A required value being empty raises an error
    gc = GenericClass.new({"id" => "1", "key" => "collection", "name" => "Collection", "lists" => []})
    assert_raises(ValidationError) do
      GenericClass.get_schema.validate(gc)
    end
  end

  def test_schema_validate_type_mismatch
    # list type
    gc = GenericClass.new({"id" => "1", "key" => "collection", "name" => "Collection", "lists" => true})
    assert_raises(ValidationError) do
      GenericClass.get_schema.validate(gc)
    end
    # list mismatch
    gc = GenericClass.new({"id" => 1, "key" => "collection", "name" => "Collection", "lists" => ["1"]})
    assert_raises(ValidationError) do
      GenericClass.get_schema.validate(gc)
    end
  end

end