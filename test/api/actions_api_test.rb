require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/storage'

class ActionsApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end
  
  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item.save!
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    @item2.save!
    @group = ItemGroup.new({'id' => 'one', 'name' => 'Group', 'group' => ['2']})
    @list = List.new({'id' => 'a', 'name' => 'list-one', 'items' => ['1', '2']})
    @list.save!
    @list2 = List.new({'id' => 'b', 'name' => 'list-two'})
    @list2.save!
  end

  def teardown
    TypeStorage.clear_test_storage
  end

  def test_move_item_success
    payload = {'item_id' => @item.id, 'from_list' => @list.id, 'to_list' => @list2.id}.to_json
    post('/api/actions/moveItem', payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal [@item2.id], @list.items
    assert_equal [@item.id], @list2.items
  end

  def test_move_item_failure
    payload = {'item_id' => 'NOT_FOUND', 'from_list' => @list.id, 'to_list' => @list2.id}.to_json
    post('/api/actions/moveItem', payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status

    payload = {'item_id' => @item.id, 'from_list' => @list.id, 'to_list' => 'NOT_FOUND'}.to_json
    post('/api/actions/moveItem', payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
  end

  def test_copy_item_success
    @list2.add_item(@item)
    payload = {'item_id' => @item2.id, 'from_list' => @list.id, 'to_list' => @list2.id}.to_json
    post('/api/actions/copyItem', payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal [@item.id, @item2.id], @list.items
    assert_equal [@item.id, @item2.id], @list2.items
  end

  def test_copy_item_failure
    payload = {'item_id' => 'NOT_FOUND', 'from_list' => @list.id, 'to_list' => @list2.id}.to_json
    post('/api/actions/copyItem', payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status

    payload = {'item_id' => @item.id, 'from_list' => @list.id, 'to_list' => 'NOT_FOUND'}.to_json
    post('/api/actions/copyItem', payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
  end

  def test_remove_item_multiple
    @list.add_item(@item)
    payload = {'item_id' => @item.id, 'from_list' => @list.id}.to_json
    post('/api/actions/removeItem', payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal [@item2.id], @list.items
  end

  def test_remove_item_by_index
    @list.add_item(@item)
    payload = {'item_id' => @item.id, 'from_list' => @list.id, 'item_index' => 0}.to_json
    post('/api/actions/removeItem', payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal [@item2.id, @item.id], @list.items
  end

  def test_remove_item_failure
    payload = {'item_id' => @item.id, 'from_list' => @list.id, 'item_index' => 1}.to_json
    post('/api/actions/removeItem', payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status

    payload = {'item_id' => @item.id, 'from_list' => 'NOT_FOUND'}.to_json
    post('/api/actions/removeItem', payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
  end

end