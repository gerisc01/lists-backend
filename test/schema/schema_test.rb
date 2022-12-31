require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../helpers'
require_relative '../../src/schema/schema'
# require_relative '../../src/type/template'

class SchemaTest < Minitest::Test

  def setup
  end

  def teardown
  end

  ########## Method Generation ##########

  def test_schema_create_methods
    gc = GenericSchemaClass.new
    # field_required (base)
    assert gc.methods.include?(:field_required)
    assert gc.methods.include?(:field_required=)
    # field_type_array_int (array)
    assert gc.methods.include?(:field_type_array_int)
    assert gc.methods.include?(:field_type_array_int=)
    assert gc.methods.include?(:add_field_type_array_int)
    assert gc.methods.include?(:remove_field_type_array_int)
    # field_type_hash_int (hash)
    assert gc.methods.include?(:field_type_hash_int)
    assert gc.methods.include?(:field_type_hash_int=)
    assert gc.methods.include?(:add_field_type_hash_int)
    assert gc.methods.include?(:upsert_field_type_hash_int)
    assert gc.methods.include?(:remove_field_type_hash_int)
  end

  ########## Schema Field Conversions ##########

  def test_schema_field_json
    @clazz = Class.new(GenericClass)
    schema = Schema.new
    schema.fields = {
      "one_field" => {:required => true},
      "all_fields" => {:required => false, :type => Array, :subtype => TypeRefClass, 'type_ref' => true, 'display_name' => 'All Fields'},
    }
    schema.apply_schema(@clazz)

    schema.fields[0].is_a?(Field)
    assert_equal 'one_field', schema.fields[0].key
    assert_equal true, schema.fields[0].required
    assert_nil schema.fields[0].display_name
    assert_nil schema.fields[0].type
    assert_nil schema.fields[0].subtype
    assert_nil schema.fields[0].type_ref
    schema.fields[1].is_a?(Field)
    assert_equal 'all_fields', schema.fields[1].key
    assert_equal false, schema.fields[1].required
    assert_equal 'All Fields', schema.fields[1].display_name
    assert_equal Array, schema.fields[1].type
    assert_equal TypeRefClass, schema.fields[1].subtype
    assert_equal true, schema.fields[1].type_ref
  end

  def test_schema_field_classes
    f1 = Field.new
    f1.key = 'one_field'
    f1.required = true
    f2 = Field.new
    f2.key = 'all_fields'
    f2.display_name = 'All Fields'
    f2.required = false
    f2.type = Array
    f2.subtype = TypeRefClass
    f2.type_ref = true

    @clazz = Class.new(GenericClass)
    schema = Schema.new
    schema.fields = [f1, f2]
    schema.apply_schema(@clazz)

    schema.fields[0].is_a?(Field)
    assert_equal 'one_field', schema.fields[0].key
    assert_equal true, schema.fields[0].required
    assert_nil schema.fields[0].display_name
    assert_nil schema.fields[0].type
    assert_nil schema.fields[0].subtype
    assert_nil schema.fields[0].type_ref
    schema.fields[1].is_a?(Field)
    assert_equal 'all_fields', schema.fields[1].key
    assert_equal false, schema.fields[1].required
    assert_equal 'All Fields', schema.fields[1].display_name
    assert_equal Array, schema.fields[1].type
    assert_equal TypeRefClass, schema.fields[1].subtype
    assert_equal true, schema.fields[1].type_ref
  end

  ########## Object Field Populations ##########

  def test_schema_populate_basic_fields
    gc = GenericSchemaClass.new
    gc.field_required = "value"
    assert_equal "value",gc.field_required
  end

  def test_schema_populate_array_fields
    gc = GenericSchemaClass.new
    # Test add and upsert with k, v params
    gc.add_field_type_array_int(1)
    assert_equal 1, gc.field_type_array_int[0]
    gc.add_field_type_array_int(2)
    assert_equal 2, gc.field_type_array_int[1]
    gc.remove_field_type_array_int(1)
    assert_equal [2], gc.field_type_array_int
    # Test value with id
    type_ref = TypeRefClass.new("1")
    gc.add_field_array_typeref(type_ref)
    assert_equal([type_ref], gc.field_array_typeref)
    gc.remove_field_array_typeref(type_ref)
    assert_equal([], gc.field_array_typeref)
  end

  def test_schema_populate_hash_fields
    gc = GenericSchemaClass.new
    # Test add and upsert with k, v params
    gc.add_field_type_hash_int("1", 1)
    assert_equal 1, gc.field_type_hash_int["1"]
    gc.upsert_field_type_hash_int("2", 2)
    assert_equal 2, gc.field_type_hash_int["2"]
    gc.upsert_field_type_hash_int("2", 3)
    assert_equal 3, gc.field_type_hash_int["2"]
    gc.remove_field_type_hash_int("1")
    assert_equal({"2" => 3}, gc.field_type_hash_int)
    # Test value with id
    type_ref = TypeRefClass.new("2")
    gc.upsert_field_hash_typeref(type_ref)
    assert_equal(type_ref, gc.field_hash_typeref["2"])
    gc.remove_field_hash_typeref(type_ref)
    assert_equal({}, gc.field_hash_typeref)
    gc.add_field_hash_typeref(type_ref)
    assert_equal(type_ref, gc.field_hash_typeref["2"])
  end

  ########## Basic Validation Test (most validation tests are in field_test.rb) ##########

  def test_schema_validation_pass
    gc = GenericSchemaClass.new
    schema = GenericSchemaClass.get_schema
    schema.fields.each { |field| field.stubs(:validate).returns(nil).once }
    schema.validate(gc)
  end

  def test_schema_validation_failure
    gc = GenericSchemaClass.new
    schema = GenericSchemaClass.get_schema
    schema.fields.each { |field| field.stubs(:validate).raises(ValidationError).never }
    schema.fields[0].stubs(:validate).raises(ValidationError).once
    assert_raises(ValidationError) do
      schema.validate(gc)
    end
  end

  # def test_schema_populate_schema
  #   # @schema.apply_schema(GenericClass)
  #   gc = GenericClass.new
  #   gc.id = "12345"
  #   gc.key = "collection"
  #   gc.lists = [1, 2, 3]
  #   gc.templates = {'one' => 'One', 'two' => 'Two'}

  #   assert_equal "12345", gc.id
  #   assert_equal "collection", gc.key
  #   assert_equal 3, gc.lists.size
  #   assert_equal 3, gc.lists[2]
  #   assert_equal 'Two', gc.templates['two']
  # end

  # def test_schema_multiple_instances
  #   gc1 = GenericClass.new
  #   gc1.id = "1"

  #   gc2 = GenericClass.new
  #   gc2.id = "2"

  #   assert_equal "1", gc1.id
  #   assert_equal "2", gc2.id
  # end

  # ## Schema validate

  # def test_schema_validate_no_errors
  #   gc = GenericClass.new({"id" => "1", "key" => "collection", "name" => "Collection", "lists" => ["1"]})
  #   GenericClass.get_schema.validate(gc)
  # end

  # def test_schema_validate_required
  #   # Missing a required value raises an error
  #   gc = GenericClass.new({"id" => "1", "key" => "collection", "name" => "Collection"})
  #   assert_raises(ValidationError) do
  #     GenericClass.get_schema.validate(gc)
  #   end
  #   # A required value being empty raises an error
  #   gc = GenericClass.new({"id" => "1", "key" => "collection", "name" => "Collection", "lists" => []})
  #   assert_raises(ValidationError) do
  #     GenericClass.get_schema.validate(gc)
  #   end
  # end

  # def test_schema_validate_type_mismatch
  #   # list type
  #   gc = GenericClass.new({"id" => "1", "key" => "collection", "name" => "Collection", "lists" => true})
  #   assert_raises(ValidationError) do
  #     GenericClass.get_schema.validate(gc)
  #   end
  #   # list mismatch
  #   gc = GenericClass.new({"id" => 1, "key" => "collection", "name" => "Collection", "lists" => ["1"]})
  #   assert_raises(ValidationError) do
  #     GenericClass.get_schema.validate(gc)
  #   end
  # end

end