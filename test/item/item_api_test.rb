require 'sinatra/base'
require 'minitest/autorun'
require 'mocha/minitest'
require 'rack/test'
require_relative '../../src/item/item_api'
require_relative '../helpers/test_list_db'
require_relative '../helpers/test_item_db'
require_relative '../../src/list/list'
require_relative '../../src/item/item'

class ItemApiTest < Minitest::Test
  include Rack::Test::Methods

  def app
    api = Api.new
    return api
  end

  def setup
    # List Setup
    List.set_db_class(TestListDb)
    @list = List.from_object({"id" => "1", "name" => "One"})
    @lists_loaded = {@list.id => @list.to_object}
    TestListDb.stubs(:file_load).returns(@lists_loaded)
    TestListDb.stubs(:persist).returns(nil)
    #Item Setup
    Item.set_db_class(TestItemDb)
    @item1 = Item.from_object({"id" => "1", "name" => "One"})
    @item2 = Item.from_object({"id" => "2", "name" => "Two"})
    @items_loaded = {@item1.id => @item1.to_object, @item2.id => @item2.to_object}
    TestItemDb.stubs(:file_load).returns(@items_loaded)
    TestItemDb.stubs(:persist).returns(nil)
  end

  def teardown
    TestListDb.teardown
    TestItemDb.teardown
  end

  ## Item list

  def test_item_lists_multiple
    get '/api/items'
    assert_equal 200, last_response.status
    assert_equal @items_loaded.values.to_json, last_response.body
  end

  def test_item_lists_empty
    TestItemDb.stubs(:file_load).returns({}).once
    get '/api/items'
    assert_equal 200, last_response.status
    assert_equal "[]", last_response.body
  end
    
  ## Item create

  def test_item_create_valid
    input = {"name" => @item1.name}
    post('/api/items', input.to_json, {"Content-Type" => "application/json"})
    assert_equal 201, last_response.status
    output = JSON.parse(last_response.body)
    assert output["id"] != nil, "Expected id to be populated"
    assert_equal @item1.name, output["name"]
  end

  def test_item_create_badRequest
    post('/api/items', "{}", {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
    output = JSON.parse(last_response.body)
    assert "Bad Request", output["error"]
    assert output["message"] != nil, "Expected error message to be populated"
  end

  ## Item update
      
  def test_item_update_valid
    put('/api/items/1', {"name" => "Updated"}.to_json, {"Content-Type" => "application/json"})
    expected_update_body = {"id" => @item1.id, "name" => "Updated"}.to_json
    assert_equal 200, last_response.status
    assert_equal expected_update_body, last_response.body
  end

  def test_item_update_invalidId
    put('/api/items/0000', {"name" => "Updated"}.to_json, {"Content-Type" => "application/json"})
    assert_equal 404, last_response.status
    output = JSON.parse(last_response.body)
    assert "Not Found", output["error"]
    assert output["message"] != nil, "Expected error message to be populated"
  end

  def test_item_update_badRequest
    put('/api/items/1', "", {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
    output = JSON.parse(last_response.body)
    assert "Bad Request", output["error"]
    assert "Invalid JSON", output["type"]
    assert output["message"] != nil, "Expected error message to be populated"
  end

  ## List delete

  def test_item_delete_success
    delete('/api/items/1')
    puts last_response.errors if last_response.status == 500
    assert_equal 204, last_response.status
    assert_equal "", last_response.body
  end

  def test_item_delete_ignoresInvalidId
    delete('/api/items/1')
    puts last_response.errors if last_response.status == 500
    assert_equal 204, last_response.status
    assert_equal "", last_response.body
  end

  ## List Items list
  
  def test_list_items_list_success
    @list.items = ["1","2"]
    List.stubs(:get).with(@list.id).returns(@list).once
    get('/api/lists/1/items')
    assert_equal 200, last_response.status
    output = JSON.parse(last_response.body)
    assert_equal 2, output.size
    assert_equal @item1.to_object, output[0]
    assert_equal @item2.to_object, output[1]
  end

  def test_list_items_list_empty
    get('/api/lists/1/items')
    assert_equal 200, last_response.status
    output = JSON.parse(last_response.body)
    assert_equal 0, output.size
  end

  ## List Items create

  def test_list_items_create
    input = {"name" => @item1.name}
    post('/api/lists/1/items', input.to_json, {"Content-Type" => "application/json"})
    assert_equal 201, last_response.status
    output = JSON.parse(last_response.body)
    itemId = output["id"]
    assert itemId != nil
    assert_equal itemId, List.get("1").items[0]
  end

end