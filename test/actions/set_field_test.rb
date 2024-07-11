require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/actions/set_field'

class SetFieldTest < MinitestWrapper

  def setup
    @template = Template.new
    @template.id = '1'
    @template.key = 'test'
    @template.display_name = 'Test'
    @template.fields = [
      {:key => 'date', :type => SchemaType::Date},
    ]
    @template.save!

    @item = Item.new({'id' => '1', 'name' => 'One', 'templates' => ['1']})
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

  def test_set_field_template_date
    set_field(@item.id, 'date', '2024-07-01')
    assert_equal '2024-07-01', @item.json['date']

    assert_raises(ListError::BadRequest) { set_field(@item.id, 'date', 'NOT_A_DATE') }

  end

  def test_set_field_not_found_failure
    assert_raises(ListError::BadRequest) { set_field('NOT_FOUND', 'name', 'Two') }
  end

end