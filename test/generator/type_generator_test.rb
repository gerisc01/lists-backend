require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/generator/type_generator'

class TypeGeneratorTest < Minitest::Test

  class TypeGeneratorTestClass
    setup_type_model(self)

    define_get(self)
    define_get_by_key(self)
    define_list(self)
    define_save!(self)
    define_delete!(self)

    # empty module just added in for stubbing purposes
    module Database
    end
  end

  def setup
    @test_schema = Schema.new
    TypeGeneratorTestClass.class_variable_set(:@@schema, @test_schema)
  end

  def teardown
  end

  # json methods
  def test_json_attr_accessor_present
    instance = TypeGeneratorTestClass.new
    assert instance.methods.include?(:json)
    assert instance.methods.include?(:json=)
  end

  # initialize()
  def test_empty_initialize
    instance = TypeGeneratorTestClass.new
    assert !instance.json['id'].nil?
  end

  def test_object_initialize
    instance = TypeGeneratorTestClass.new({'id' => '1'})
    assert_equal '1', instance.json['id']
  end

  # validate()
  def test_schema_validate_success
    instance = TypeGeneratorTestClass.new
    @test_schema.stubs(:validate).with(instance).returns(nil).once
    assert_nil instance.validate
  end

  def test_schema_validate_failure
    instance = TypeGeneratorTestClass.new
    @test_schema.stubs(:validate).with(instance).raises(ListError::Validation).once
    assert_raises(ListError::Validation) do
      instance.validate
    end
  end

  # from_object()
  def test_from_object
    json = {'id' => '1'}
    TypeGeneratorTestClass.stubs(:new).with(json).once
    TypeGeneratorTestClass.from_object(json)
  end

  # to_object()
  def test_to_object
    json = {'id' => '1'}
    instance = TypeGeneratorTestClass.new(json)
    assert_equal json, instance.to_object
  end

  # merge!()
  def test_merge
    json = {'id' => '1', 'description' => 'An Old Description'}
    newJson = {'id' => '2', 'name' => 'New Name'}
    instance = TypeGeneratorTestClass.new(json)
    instance.merge!(newJson)
    assert_equal '2', instance.json['id']
    assert_equal 'New Name', instance.json['name']
    assert_equal 'An Old Description', instance.json['description']
  end

  # get()
  def test_get_found
    db_instance = TypeGeneratorTestClass.new({'id' => '1', 'name' => 'A Name'})
    TypeGeneratorTestClass::Database.stubs(:get).with('1').returns(db_instance).once
    instance = TypeGeneratorTestClass.get('1')
    assert_equal db_instance.json['id'], instance.json['id']
    assert_equal db_instance.json['name'], instance.json['name']
  end

  def test_get_not_found
    TypeGeneratorTestClass::Database.stubs(:get).with('2').returns(nil).once
    instance = TypeGeneratorTestClass.get('2')
    assert_nil instance
  end

  # get_by_key()
  def test_get_by_key_found
    db_instance_1 = TypeGeneratorTestClass.new({'id' => '1', 'key' => 'one', 'name' => 'One Name'})
    db_instance_2 = TypeGeneratorTestClass.new({'id' => '2', 'key' => 'two', 'name' => 'Two Name'})
    TypeGeneratorTestClass::Database.stubs(:list).returns([db_instance_1, db_instance_2]).once
    instance = TypeGeneratorTestClass.get_by_key('two')
    assert_equal db_instance_2.json['id'], instance.json['id']
    assert_equal db_instance_2.json['key'], instance.json['key']
    assert_equal db_instance_2.json['name'], instance.json['name']
  end

  def test_get_by_key_not_found
    db_instance_1 = TypeGeneratorTestClass.new({'id' => '1', 'key' => 'one', 'name' => 'One Name'})
    db_instance_2 = TypeGeneratorTestClass.new({'id' => '2', 'key' => 'two', 'name' => 'Two Name'})
    TypeGeneratorTestClass::Database.stubs(:list).returns([db_instance_1, db_instance_2]).once
    instance = TypeGeneratorTestClass.get_by_key('three')
    assert_nil instance
  end

  # list()
  def test_list_found
    db_instance_1 = TypeGeneratorTestClass.new({'id' => '1', 'key' => 'one', 'name' => 'One Name'})
    db_instance_2 = TypeGeneratorTestClass.new({'id' => '2', 'key' => 'two', 'name' => 'Two Name'})
    TypeGeneratorTestClass::Database.stubs(:list).returns([db_instance_1, db_instance_2]).once
    results = TypeGeneratorTestClass.list
    assert_equal 2, results.size
    assert_equal '1', results[0].json['id']
    assert_equal '2', results[1].json['id']
  end

  def test_list_not_found
    TypeGeneratorTestClass::Database.stubs(:list).returns([]).once
    results = TypeGeneratorTestClass.list
    assert_empty results
  end

  # save!()
  def test_save_success
    instance = TypeGeneratorTestClass.new({'id' => '1'})
    TypeGeneratorTestClass::Database.stubs(:save).with(instance).once
    instance.stubs(:validate).returns(nil).once
    instance.save!
  end

  def test_save_fail
    instance = TypeGeneratorTestClass.new({'id' => '1'})
    TypeGeneratorTestClass::Database.stubs(:save).with(instance).never
    instance.stubs(:validate).raises(ListError::Validation).once
    assert_raises(ListError::Validation) do
      instance.save!
    end
  end

  # delete!()
  def test_delete_success
    instance = TypeGeneratorTestClass.new({'id' => '2'})
    TypeGeneratorTestClass::Database.stubs(:delete).with('2').once
    instance.delete!
  end

  def test_delete_fail
    instance = TypeGeneratorTestClass.new
    instance.json['id'] = nil
    TypeGeneratorTestClass::Database.stubs(:delete).never
    assert_raises(ListError::BadRequest) do
      instance.delete!
    end
  end

end