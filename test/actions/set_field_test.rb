require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/actions/set_field'

class SetFieldTest < MinitestWrapper

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_set_field
    set_field(@item.id, 'name', 'Two')
    assert_equal 'Two', @item.name
  end

  def test_set_field_key_not_found
    assert_raises(ListError::BadRequest) { set_field(@item.id, 'NOT_FOUND', 'Two') }
  end

  def test_set_field_not_found_failure
    assert_raises(ListError::BadRequest) { set_field('NOT_FOUND', 'name', 'Two') }
  end

end