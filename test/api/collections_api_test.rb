require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/storage'

class CollectionsApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end

  def setup
    @template = Template.new({'id' => 'i', 'key' => 'k1', 'display_name' => 'd1', 'fields' => [{ 'key' => 'name', 'display_name' => 'Name', 'type' => 'String'}]})
    @template2 = Template.new({'id' => 'j', 'key' => 'k2', 'display_name' => 'd2', 'fields' => [{ 'key' => 'name', 'display_name' => 'Name', 'type' => 'String'}]})
    [ @template, @template2 ].each { |t| t.save! }
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    [ @item, @item2 ].each { |i| i.save! }
    @list = List.new({'id' => 'a', 'name' => 'Uno', 'items' => []})
    @list2 = List.new({'id' => 'b', 'name' => 'Dos', 'template' => 'i', 'items' => []})
    @list2.add_item_with_template_ref(@item)
    @list2.add_item_with_template_ref(@item2)
    @list3 = List.new({'id' => 'c', 'name' => 'Tres', 'template' => 'j', 'items' => []})
    @list3.add_item_with_template_ref(@item)
    [ @list, @list2, @list3 ].each { |l| l.save! }
    @collection = Collection.new({'id' => 'col', 'name' => 'Test', 'lists' => ['a', 'b', 'c'], 'templates' => ['i', 'j']})
    @collection.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_remove_template
    assert_equal ['i', 'j'], @item.templates
    delete("/api/collections/col/templates/i")
    assert_equal ['j'], @item.templates
    assert_equal [], @item2.templates
    assert_nil @list2.template
    assert_equal 'j', @list3.template
  end



end