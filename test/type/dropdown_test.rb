require_relative '../minitest_wrapper'
require_relative '../helpers'
require_relative '../../src/type/template'
require_relative '../../src/type/template_types/dropdown'
require_relative '../../src/type/item'
require_relative '../../src/type/list'

class DropdownTest < MinitestWrapper

  def setup
    @item = Item.new({'id' => '11', 'name' => 'Test'})
    @item2 = Item.new({'id' => '12', 'name' => 'Test2'})
    @list = List.new({'id' => '1', 'name' => 'Test List', 'items' => ['11', '12']})
    [@item, @item2, @list].each { |it| it.save!}

    @template = Template.new
    @template.id = '1'
    @template.key = 'test'
    @template.display_name = 'Test'
    @template.fields = [
      {:key => 'dropdown', :required => false, :type => SchemaType::Dropdown, :display_name => 'Dropdown', :static_options => ['1','2']},
    ]
    @template.save!

    @template2 = Template.new
    @template2.id = '2'
    @template2.key = 'test-list'
    @template2.display_name = 'Test List'
    @template2.fields = [
      {'key' => 'dropdown', 'required' => false, 'type' => SchemaType::Dropdown, 'display_name' => 'Dropdown', 'list_options' => '1'},
    ]
    @template2.save!
  end

  def teardown
    TypeStorage.clear_test_storage
  end

  def test_dropdown_def_validation_missing_option
    temp = Template.new
    temp.id = '100'
    temp.key = 'invalid-list'
    temp.display_name = 'Invalid List'
    temp.fields = [
      {:key => 'dropdown', :required => false, :type => SchemaType::Dropdown, :display_name => 'Dropdown'},
    ]
    assert_raises(Schema::ValidationError) { temp.validate }
  end

  def test_dropdown_def_validation_too_many_options
    temp = Template.new
    temp.id = '100'
    temp.key = 'invalid-list'
    temp.display_name = 'Invalid List'
    temp.fields = [
      {:key => 'dropdown', :required => false, :type => SchemaType::Dropdown, :display_name => 'Dropdown', :static_options => ['1','2'], :list_options => '1'},
    ]
    assert_raises(Schema::ValidationError) { temp.validate }
  end

  def test_dropdown_def_validation_static_wrong_type
    temp = Template.new
    temp.id = '100'
    temp.key = 'invalid-list'
    temp.display_name = 'Invalid List'
    temp.fields = [
      {:key => 'dropdown', :required => false, :type => SchemaType::Dropdown, :display_name => 'Dropdown', :static_options => '1'},
    ]
    assert_raises(Schema::ValidationError) { temp.validate }
  end

  def test_dropdown_def_validation_list_doesnt_exist
    temp = Template.new
    temp.id = '100'
    temp.key = 'invalid-list'
    temp.display_name = 'Invalid List'
    temp.fields = [
      {:key => 'dropdown', :required => false, :type => SchemaType::Dropdown, :display_name => 'Dropdown', :list_options => 'MISSING'},
    ]
    assert_raises(Schema::ValidationError) { temp.validate }
  end

  def test_static_dropdown
    item = Item.new({'id' => '1', 'name' => 'Test', 'dropdown' => '2', 'templates' => ['1']})
    item.validate
  end

  def test_static_dropdown_failure
    item = Item.new({'id' => '1', 'name' => 'Test', 'dropdown' => '3', 'templates' => ['1']})
    assert_raises(Schema::ValidationError) { item.validate }
  end

  def test_list_dropdown
    item = Item.new({'id' => '1', 'name' => 'Test', 'dropdown' => '12', 'templates' => ['2']})
    item.validate
  end

  def test_list_dropdown_list_failure
    item = Item.new({'id' => '1', 'name' => 'Test', 'dropdown' => '13', 'templates' => ['2']})
    assert_raises(Schema::ValidationError) { item.validate }
  end
end