require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/generator/type_generator'
require_relative '../../src/generator/db_generator'

class DbGeneratorTest < Minitest::Test

  class DbGeneratorTestClass
    setup_type_model(self)

    module Database
      @@file_name = 'data/test-collections.json'
  
      file_based_db_and_cache(self, DbGeneratorTestClass)

      define_db_get(self)
      define_db_list(self)
      define_db_save(self)
      define_db_delete(self)
    end
  end

  def setup
    @filename = 'data/test-collections.json'
    @loaded_objs = {
      '1' => DbGeneratorTestClass.new({'id' => '1', 'name' => 'One', 'key' => 'one'}),
      '2' => DbGeneratorTestClass.new({'id' => '2', 'name' => 'Two', 'key' => 'two'})
    }
    @file_objs = {
      '1' => @loaded_objs['1'].json,
      '2' => @loaded_objs['2'].json
    }
  end

  def teardown
    DbGeneratorTestClass::Database.cache_clear
    File.delete(@filename) if File.exist?(@filename)
  end

  # persist() && file_write() && load() && file_load()
  def test_persist_load_cycle_empty
    # Write empty works successfully
    DbGeneratorTestClass::Database.cache_clear
    DbGeneratorTestClass::Database.persist
    assert File.exist?(@filename)
    json_str = File.read(@filename)
    expected_str = {}.to_json
    assert_equal expected_str, json_str

    # Read empty works successfully
    DbGeneratorTestClass::Database.load()
    objs = DbGeneratorTestClass::Database.class_variable_get(:@@loaded_objs)
    expected_objs = {}
    assert_equal expected_objs, objs
  end

  def test_persist_load_cycle_multiple
    DbGeneratorTestClass::Database.class_variable_set(:@@loaded_objs, @loaded_objs)
    DbGeneratorTestClass::Database.persist()
    assert File.exist?(@filename)
    json_str = File.read(@filename)
    expected_str = @file_objs.to_json
    assert_equal expected_str, json_str

    DbGeneratorTestClass::Database.load()
    objs = DbGeneratorTestClass::Database.class_variable_get(:@@loaded_objs)
    assert objs['1'].is_a?(DbGeneratorTestClass)
    assert_equal objs['1'].json['id'], '1'
    assert_equal objs['1'].json['name'], 'One'
    assert objs['2'].is_a?(DbGeneratorTestClass)
    assert_equal objs['2'].json['id'], '2'
    assert_equal objs['2'].json['name'], 'Two'
  end

  # get()
  def test_get_success
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    instance = DbGeneratorTestClass::Database.get('1')
    assert instance.is_a?(DbGeneratorTestClass)
    assert_equal '1', instance.json['id']
    assert_equal 'One', instance.json['name']
  end

  def test_get_not_found
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    instance = DbGeneratorTestClass::Database.get('100')
    assert_nil instance
  end

  def test_get_empty
    DbGeneratorTestClass::Database.stubs(:file_load).returns({}).once
    instance = DbGeneratorTestClass::Database.get('1')
    assert_nil instance
  end

  def test_get_uses_cache
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    DbGeneratorTestClass::Database.get('1')
    DbGeneratorTestClass::Database.get('1')
  end

  # list()
  def test_list_success
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    instances = DbGeneratorTestClass::Database.list
    assert_equal 2, instances.size
    instance_one = instances[0]
    assert instance_one.is_a?(DbGeneratorTestClass)
    assert_equal '1', instance_one.json['id']
    assert_equal 'One', instance_one.json['name']
    instance_two = instances[1]
    assert instance_two.is_a?(DbGeneratorTestClass)
    assert_equal '2', instance_two.json['id']
    assert_equal 'Two', instance_two.json['name']
  end

  def test_list_empty
    DbGeneratorTestClass::Database.stubs(:file_load).returns({}).once
    instances = DbGeneratorTestClass::Database.list
    assert_equal [], instances
  end

  def test_list_uses_cache
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    DbGeneratorTestClass::Database.list
    DbGeneratorTestClass::Database.list
  end

  # save()
  def test_save_success
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    DbGeneratorTestClass::Database.stubs(:persist).once
    instance = DbGeneratorTestClass.new({'id' => '3', 'name' => 'Three'})
    DbGeneratorTestClass::Database.save(instance)
    objs = DbGeneratorTestClass::Database.class_variable_get(:@@loaded_objs)
    assert objs.has_key?('3')
    saved_instance = objs['3']
    assert_equal '3', saved_instance.json['id']
    assert_equal 'Three', saved_instance.json['name']
  end

  def test_save_over_existing
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    DbGeneratorTestClass::Database.stubs(:persist).once
    instance = DbGeneratorTestClass.new({'id' => '1', 'name' => 'Uno'})
    DbGeneratorTestClass::Database.save(instance)
    objs = DbGeneratorTestClass::Database.class_variable_get(:@@loaded_objs)
    assert objs.has_key?('1')
    saved_instance = objs['1']
    assert_equal '1', saved_instance.json['id']
    assert_equal 'Uno', saved_instance.json['name']
  end

  def test_save_uses_cache
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    DbGeneratorTestClass::Database.stubs(:persist).twice
    DbGeneratorTestClass::Database.save(DbGeneratorTestClass.new({'id' => '3', 'name' => 'Three'}))
    DbGeneratorTestClass::Database.save(DbGeneratorTestClass.new({'id' => '4', 'name' => 'Four'}))
  end

  # delete()
  def test_delete_success
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    DbGeneratorTestClass::Database.stubs(:persist).once
    DbGeneratorTestClass::Database.delete('1')
    objs = DbGeneratorTestClass::Database.class_variable_get(:@@loaded_objs)
    assert !objs.has_key?('1')
    assert_equal 1, objs.size
  end

  def test_delete_ignored
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    DbGeneratorTestClass::Database.stubs(:persist).once
    DbGeneratorTestClass::Database.delete('3')
    objs = DbGeneratorTestClass::Database.class_variable_get(:@@loaded_objs)
    assert !objs.has_key?('3')
    assert_equal 2, objs.size
  end

  def test_delete_use_cache
    DbGeneratorTestClass::Database.stubs(:file_load).returns(@file_objs).once
    DbGeneratorTestClass::Database.stubs(:persist).twice
    DbGeneratorTestClass::Database.delete('1')
    DbGeneratorTestClass::Database.delete('2')
  end

  # save synchronization
  def test_save_synchronize
    val1 = @loaded_objs['1']
    val2 = @loaded_objs['2']

    threads = [
      Thread.new { DbGeneratorTestClass::Database.save(val1) },
      Thread.new { DbGeneratorTestClass::Database.save(val2) }
    ]

    while !threads.select {|t| t.alive?}.empty? do
      true
    end

    assert File.exist?(@filename)
    json_str = File.read(@filename)
    expected_str = {'1' => val1.json, '2' => val2.json}.to_json
    assert_equal expected_str, json_str
  end

end