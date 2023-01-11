require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../helpers'
require_relative '../../src/schema/schema'
require_relative '../../src/generator/type_generator'

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
    type_ref = TypeRefClass.new({'id' => '1'})
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
    type_ref = TypeRefClass.new({'id' => '2'})
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
    schema.fields.each { |field| field.stubs(:validate).raises(ListError::Validation).never }
    schema.fields[0].stubs(:validate).raises(ListError::Validation).once
    assert_raises(ListError::Validation) do
      schema.validate(gc)
    end
  end

  def test_empty_schema_validate_success
    empty_schema_instance = EmptySchemaClass.new
    schema = EmptySchemaClass.get_schema
    schema.validate(empty_schema_instance)
  end

  ########## Field accessors translate to schema types ##########

  def test_schema_accessor_transform
    @type_clazz = Class.new(GenericClass)
    setup_type_model(@type_clazz)
    typeschema = Schema.new
    typeschema.fields = {
      "id" => {:required => true, :type => String},
      "number" => {:required => true, :type => Integer}
    }
    typeschema.apply_schema(@type_clazz)

    @clazz = Class.new(GenericClass)
    schema = Schema.new
    schema.fields = {
      "string_field" => {:type => String},
      "type_field" => {:type => @type_clazz},
      "array_field" => {:type => Array, :subtype => @type_clazz},
      "hash_field" => {:type => Hash, :subtype => @type_clazz}
    }
    schema.apply_schema(@clazz)

    json = {
      'string_field' => 'Something Good!',
      'type_field' => {'id' => '1', 'number' => 11},
      'array_field' => [{'id' => '2', 'number' => 22},{'id' => '3', 'number' => 33}],
      'hash_field' => {'4' => {'id' => '4', 'number' => 44}, '5' => {'id' => '5', 'number' => 55}}
    }

    c = @clazz.new
    c.json = json
    assert_equal 'Something Good!', c.string_field
    assert c.type_field.is_a?(@type_clazz)
    assert_equal '1', c.type_field.id
    assert_equal 11, c.type_field.number
    assert c.array_field[0].is_a?(@type_clazz)
    assert_equal '2', c.array_field[0].id
    assert_equal 22, c.array_field[0].number
    assert c.array_field[1].is_a?(@type_clazz)
    assert_equal '3', c.array_field[1].id
    assert_equal 33, c.array_field[1].number
    assert c.hash_field['4'].is_a?(@type_clazz)
    assert_equal '4', c.hash_field['4'].id
    assert_equal 44, c.hash_field['4'].number
    assert c.hash_field['5'].is_a?(@type_clazz)
    assert_equal '5', c.hash_field['5'].id
    assert_equal 55, c.hash_field['5'].number
    assert_equal json, c.json
  end

  def test_schema_accessor_transform_typeref_toplevel
    @clazz = Class.new(GenericClass)
    schema = Schema.new
    schema.fields = {
      "type_field" => {:type => TypeRefClass, :type_ref => true}
    }
    schema.apply_schema(@clazz)

    c = @clazz.new
    c.json = {'type_field' => {'id' => '1', 'number' => 11}}
    assert c.type_field.is_a?(String)
    assert_equal '1', c.type_field
  end

  def test_schema_accessor_transform_typeref_array
    @clazz = Class.new(GenericClass)
    schema = Schema.new
    schema.fields = {
      "array_field" => {:type => Array, :subtype => TypeRefClass, :type_ref => true}
    }
    schema.apply_schema(@clazz)

    c = @clazz.new
    c.json = {'array_field' => [{'id' => '2', 'number' => 22},{'id' => '3', 'number' => 33}]}
    assert c.array_field[0].is_a?(String)
    assert_equal '2', c.array_field[0]
    assert c.array_field[1].is_a?(String)
    assert_equal '3', c.array_field[1]
  end
end