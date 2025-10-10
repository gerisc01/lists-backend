require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/actions/add_item_to_field'

class AddItemToFieldTest < MinitestWrapper

  def setup
    @template = Template.new
    @template.id = 'addItemFieldTestTemplate'
    @template.key = 'addItemFieldTestTemplate'
    @template.display_name = 'addItemFieldTestTemplate'
    @template.fields = [
      {:key => 'today', :type => SchemaType::Date},
      {:key => 'next_dates', :type => Array, :subtype => SchemaType::Date},
    ]
    @template.save!

    @item = Item.new({'id' => '1', 'name' => 'One', 'templates' => ['addItemFieldTestTemplate']})
    @item.save!
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    @item2.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_add_child_to_field
    add_item_to_field(@item.id, 'children', @item2.id)
    assert_equal ['2'], @item.children
  end

  def test_add_field_template_field
    add_item_to_field(@item.id, 'next_dates', '2025-01-01')
    assert_equal ['2025-01-01'], @item.json['next_dates']

    assert_raises(ListError::BadRequest) { add_item_to_field(@item.id, 'next_dates', 'NOT_A_DATE') }
  end

  def test_add_field_non_array_failure
    assert_raises(ListError::BadRequest) { add_item_to_field(@item.id, 'today', '100') }
  end

  def test_add_field_not_found_failure
    assert_raises(ListError::BadRequest) { add_item_to_field(@item.id, 'children', '100') }
  end

end
