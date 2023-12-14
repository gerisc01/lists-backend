require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../../src/api/lists_api'
require_relative '../../src/api/collections_api'
require_relative '../../src/api/items_api'

class ListApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    api = Api.new
    return api
  end
  
  def setup
    @item = Item.new({'id' => '1'})
    @item2 = Item.new({'id' => '2'})
    @group = ItemGroup.new({'id' => 'one', 'name' => 'Group', 'group' => ['2']})
    @list = List.new({'id' => 'a'})
    @list2 = List.new({'id' => 'b', 'items' => ['1', '2']})
  end

  def teardown
    mocha_teardown
  end

  # add item
  def test_add_item
    Item.stubs(:get).with('1').returns(@item).once
    List.stubs(:get).with('a').returns(@list).once
    @list.stubs(:add_item).with(@item).once
    @list.stubs(:save!).once
    put('/api/lists/a/addItem/1')
    assert_equal 200, last_response.status
  end

  # remove item
  def test_remove_item
    Item.stubs(:get).with('1').returns(@item).once
    List.stubs(:get).with('a').returns(@list).once
    @list.stubs(:remove_item).with(@item).once
    @list.stubs(:save!).once
    put('/api/lists/a/removeItem/1')
    assert_equal 200, last_response.status
  end

  # move item
  def test_list_move_item_success
    Item.stubs(:get).with('1').returns(@item).once
    List.stubs(:get).with('a').returns(@list).once
    List.stubs(:get).with('b').returns(@list2).once
    @list.stubs(:remove_item).with(@item).once
    @list.stubs(:save!).once
    @list2.stubs(:add_item).with(@item).once
    @list2.stubs(:save!).once
    put('/api/items/1/moveItem', {'fromList' => 'a', 'toList' => 'b'}.to_json, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
  end

  def test_list_move_item_fail
    put('/api/items/1/moveItem', {'fromList' => 'a'}.to_json, {"Content-Type" => "application/json"})
    assert last_response.status != 200

    put('/api/items/1/moveItem', {'toList' => 'a'}.to_json, {"Content-Type" => "application/json"})
    assert last_response.status != 200

    put '/api/items/1/moveItem'
    assert last_response.status != 200
  end

  # get items from list
  def test_list_get_items
    List.stubs(:get).with('b').returns(@list2).once
    Item.stubs(:get).with('1').returns(@item).once
    Item.stubs(:get).with('2').returns(@item2).once
    get '/api/lists/b/items'
    assert_equal 200, last_response.status
    assert_equal [@item.json, @item2.json].to_json, last_response.body
  end

  # create item on list
  def test_list_create_item
    List.stubs(:get).with('a').returns(@list).once
    Item.stubs(:new).with(@item2.json).returns(@item2).once
    @list.stubs(:add_item).with(@item2).once
    @list.stubs(:save!).once
    post('/api/lists/a/items', @item2.json.to_json, {"Content-Type" => "application/json"})
    assert_equal 201, last_response.status
    assert_equal  @item2.json.to_json, last_response.body
  end

  # get items from collection, including groups
  def test_collection_get_items
    Item.stubs(:get).with('1').returns(@item).once
    Item.stubs(:get).with('2').returns(@item2).once
    Item.stubs(:get).with('one').returns(nil).once
    ItemGroup.stubs(:get).with('one').returns(@group).once
    group_list = List.new({'id' => 'gr_list', 'items' => ['1', 'one']})
    List.stubs(:get).with('gr_list').returns(group_list).once
    collection = Collection.new({'id' => '1', 'lists' => ['gr_list']})
    Collection.stubs(:get).with('1').returns(collection).once

    get('/api/collections/1/listItems')
    assert_equal 200, last_response.status
    assert_equal  [@item.json, @group.json, @item2.json].to_json, last_response.body
  end

end