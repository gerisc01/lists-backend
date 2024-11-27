require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../../src/exceptions_api'
require_relative '../../src/api/lists_api'
require_relative '../../src/api/collections_api'
require_relative '../../src/api/items_api'

class Api
  set :show_exceptions => :after_handler
end

class ListApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    api = Api.new
    return api
  end
  
  def setup
    @template = Template.new({'id' => 'i', 'key' => 'k1', 'display_name' => 'd1', 'fields' => [{ 'key' => 'name', 'display_name' => 'Name', 'type' => 'String'}]})
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    @group = ItemGroup.new({'id' => 'one', 'name' => 'Group', 'group' => ['2']})
    [ @item, @item2, @group ].each { |i| i.save! }
    @list = List.new({'id' => 'a', 'name' => 'Uno'})
    @list2 = List.new({'id' => 'b', 'name' => 'Dos', 'items' => ['1', '2']})
    [ @list, @list2 ].each { |l| l.save! }
    @action = Action.new({
      'id' => 'a',
      'name' => 'action',
      'steps' => [
        {'type' => 'moveItem', 'fixed_params' => {'to_list' => 'a'}}
      ],
      'inputs' => {
        'item_id' => 'ItemGeneric',
        'from_list' => 'List'
      }
    })
    @action.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  # add item
  def test_add_item
    put('/api/lists/a/addItem/1')
    assert_equal 200, last_response.status
  end

  # remove item
  def test_remove_item
    put('/api/lists/a/removeItem/1')
    assert_equal 200, last_response.status
  end

  # get items from list
  def test_list_get_items
    get '/api/lists/b/items'
    assert_equal 200, last_response.status
    assert_equal [@item.json, @item2.json].to_json, last_response.body
  end

  # create item on list
  def test_list_create_item
    new_item = {'id' => 'new', 'name' => 'New Item'}
    post('/api/lists/a/items', new_item.to_json, {"Content-Type" => "application/json"})
    assert_equal 201, last_response.status
    assert_equal  new_item.to_json, last_response.body
  end

  def test_list_create_item_failure_existing_id
    post('/api/lists/a/items', @item2.json.to_json, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
    assert_equal  "Item with id '2' already exists", JSON.parse(last_response.body)['message']
  end

  def test_list_with_template_create_item
    @list.template = @template
    @list.save!
    new_item = {'id' => 'new', 'name' => 'New Item'}
    post('/api/lists/a/items', new_item.to_json, {"Content-Type" => "application/json"})
    assert_equal 201, last_response.status
    assert_equal  'new', JSON.parse(last_response.body)['id']
    assert_equal ['i'], Item.get('new').templates
  end

  def test_list_with_template_update_item
    @list.template = @template
    @list.save!
    put('/api/lists/a/items/1', {'name' => 'New Name'}.to_json, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal  '1', JSON.parse(last_response.body)['id']
    assert_equal  'New Name', JSON.parse(last_response.body)['name']
    assert_equal ['i'], Item.get('1').templates
  end

  def test_list_with_template_update_item_fail_template
    @list.template = @template
    @list.save!
    put('/api/lists/a/items/1', {'name' => ''}.to_json, {"Content-Type" => "application/json"})
    assert last_response.status != 200
    assert_nil Item.get('1').templates
  end

  def test_list_with_template_add_and_remove_item
    @list.template = @template
    @list.save!
    put('/api/lists/a/addItem/2', {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert last_response.body.empty?
    assert_equal ['i'], Item.get(@item2.id).templates
    put('/api/lists/a/removeItem/2', {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert last_response.body.empty?
    assert_equal [], Item.get(@item2.id).templates
  end

  # get items from collection, including groups
  def test_collection_get_items
    group_list = List.new({'id' => 'gr_list', 'items' => ['1', 'one']})
    List.stubs(:get).with('gr_list').returns(group_list).once
    collection = Collection.new({'id' => '1', 'lists' => ['gr_list']})
    Collection.stubs(:get).with('1').returns(collection).once

    get('/api/collections/1/listItems')
    assert_equal 200, last_response.status
    assert_equal  [@item.json, @group.json, @item2.json].to_json, last_response.body
  end

  def test_list_add_action
    post('/api/lists/a/actions', @action.json.to_json, {"Content-Type" => "application/json"})
    assert_equal 201, last_response.status
    assert_equal  @list.json.to_json, last_response.body
  end

end