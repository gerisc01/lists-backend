require_relative '../minitest_wrapper'
require_relative '../helpers'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/type/template'

class ListTest < MinitestWrapper

  def setup
    @template = Template.new
    @template.key = 'test'
    @template.display_name = 'Test'
    @template.fields = [
      {:key => 'field1', :required => true},
      {:key => 'field2', :type => String},
    ]
    Template.stubs(:exist?).with(@template.id).returns(true)
    Template.stubs(:get).with(@template.id).returns(@template)

    @list = List.new({'name' => 'Test List'})
    @list.template = @template
  end

  def teardown
    mocha_teardown
  end

  def test_list_add_item_success
    item_json = {
      'name' => 'Successful Item',
      'field1' => 2,
      'field2' => 'anything'
    }
    item = Item.new(item_json)
    Item.stubs(:exist?).with(item.id).returns(true)
    assert @list.items.nil? || @list.items.empty?
    @list.add_item_with_template_ref(item)
    assert @list.items.include?(item.id)
  end

  def test_list_add_item_failure 
    item_json = {
      'name' => 'Successful Item',
      'field2' => 'anything'
    }
    item = Item.new(item_json)
    assert_raises(Schema::ValidationError) do
      @list.add_item_with_template_ref(item)
    end
  end

end