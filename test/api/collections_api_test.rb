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
    @action = Action.new({'id' => 'x', 'name' => 'a1', 'steps' => [{ 'type' => 'moveItem', 'fixed_params' => {}, 'input_params' => []}]})
    @action2 = Action.new({'id' => 'y', 'name' => 'a2', 'steps' => [{ 'type' => 'moveItem', 'fixed_params' => {}, 'input_params' => []}]})
    [ @action, @action2 ].each { |t| t.save! }
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    [ @item, @item2 ].each { |i| i.save! }
    @list = List.new({'id' => 'a', 'name' => 'Uno', 'actions' => ['x', 'y'], 'items' => []})
    @list2 = List.new({'id' => 'b', 'name' => 'Dos', 'template' => 'i', 'actions' => ['x'], 'items' => []})
    @list2.add_item_with_template_ref(@item)
    @list2.add_item_with_template_ref(@item2)
    @list3 = List.new({'id' => 'c', 'name' => 'Tres', 'template' => 'j', 'items' => []})
    @list3.add_item_with_template_ref(@item)
    [ @list, @list2, @list3 ].each { |l| l.save! }
    @collection = Collection.new({'id' => 'col', 'name' => 'Test', 'lists' => ['a', 'b', 'c'], 'templates' => ['i', 'j'],
       'actions' => ['x','y'], 'groups' => [{'key' => 'g1', 'name' => 'Group 1', 'lists' => ['a', 'b'], 'actions' => ['y']}]})
    @collection.save!
    @collection2 = Collection.new({'id' => 'col2', 'name' => 'Test 2', 'lists' => ['a']})
    @collection2.save!
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

  def test_remove_template_minimal_collection
    delete("/api/collections/col2/templates/i")
    assert_nil @collection2.actions
  end

  def test_remove_action_list
    assert_equal ['x', 'y'], @list.actions
    delete("/api/collections/col/actions/x")
    assert_equal ['y'], @list.actions
    assert_equal [], @list2.actions
    assert_nil @list3.actions
    assert_equal ['y'], @collection.actions
  end

  def test_remove_action_list_group
    assert_equal ['y'], @collection.json['groups'][0]['actions']
    delete("/api/collections/col/actions/y")
    assert_equal [], @collection.json['groups'][0]['actions']
    assert_equal ['x'], @collection.actions
  end

  def test_remove_action_minimal_collection
    delete("/api/collections/col2/actions/y")
    assert_nil @collection2.actions
  end



end