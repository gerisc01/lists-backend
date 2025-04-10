require_relative '../minitest_wrapper'
require_relative '../helpers'
require_relative '../../src/type/template'
require_relative '../../src/type/template_types/integer_patch'
require_relative '../../src/type/item'
require_relative '../../src/type/list'

class IntegerPatchTest < MinitestWrapper

  def setup
    @template = Template.new
    @template.id = '1'
    @template.key = 'test'
    @template.display_name = 'Test'
    @template.fields = [
      {:key => 'int', :required => false, :type => Integer, :display_name => 'Int'},
    ]
    @template.save!
  end

  def teardown
    TypeStorage.clear_test_storage
  end

  def test_integer_patch_type_empty_success
    item = Item.new({'id' => '1', 'name' => 'Test', 'templates' => ['1']})
    item.validate
  end

  def test_integer_patch_type_match_str
    item = Item.new({'id' => '1', 'name' => 'Test', 'int' => '1', 'templates' => ['1']})
    item.validate
  end

  def test_integer_patch_type_match_int
    item = Item.new({'id' => '1', 'name' => 'Test', 'int' => 1, 'templates' => ['1']})
    item.validate
  end

  def test_integer_patch_type_match_failure
    item = Item.new({'id' => '1', 'name' => 'Test', 'int' => ['1'], 'templates' => ['1']})
    assert_raises(Schema::ValidationError) { item.validate }
  end

  def test_integer_patch_str_success
    item = Item.new({'id' => '1', 'name' => 'Test', 'days' => '1', 'templates' => ['1']})
    item.validate
  end

  def test_integer_patch_str_failure
    item = Item.new({'id' => '1', 'name' => 'Test', 'days' => 'abc', 'templates' => ['1']})
    item.validate
  end

  def test_integer_patch_int_success
    item = Item.new({'id' => '1', 'name' => 'Test', 'days' => 1, 'templates' => ['1']})
    item.validate
  end

  def test_integer_patch_int_float_failure
    item = Item.new({'id' => '1', 'name' => 'Test', 'days' => 1.9, 'templates' => ['1']})
    item.validate
  end

end