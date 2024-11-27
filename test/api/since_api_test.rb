require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/storage'

class SinceApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end
  
  def setup
    @item = Item.new({'id' => '1', 'name' => 'Test', 'updated_at' => '2024-12-31T12:52:08Z'})
    @item2 = Item.new({'id' => '2', 'name' => 'Test2', 'updated_at' => '2024-12-31T23:52:08Z'})
    @item3 = Item.new({'id' => '3', 'name' => 'Test3', 'updated_at' => '2025-01-01T01:52:08Z'})
    @item4 = Item.new({'id' => '4', 'name' => 'Test4', 'updated_at' => '2025-01-01T21:52:08Z'})
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_since_no_since
    Item.stubs(:list).returns([@item, @item2, @item3, @item4])
    get('/api/items', {'Content-Type' => 'application/json'})
    assert_equal 200, last_response.status
    objects = JSON.parse(last_response.body)
    assert_equal 4, objects.length
  end

  def test_since_middle
    Item.stubs(:list).returns([@item, @item2, @item3, @item4])
    get('/api/items?since=2025-01-01T00:00:00Z', {'Content-Type' => 'application/json'})
    assert_equal 200, last_response.status
    resp = JSON.parse(last_response.body)
    objects = resp['objects']
    assert_equal 0, resp['deleted_ids'].length
    assert_equal 2, objects.length
    assert_equal '3', objects[0]['id']
    assert_equal '4', objects[1]['id']
  end

  def test_since_deleted
    [@item, @item2, @item3, @item4].each { |item| item.json['deleted'] = true }

    Item.stubs(:list).returns([@item, @item2, @item3, @item4])
    get('/api/items?since=2025-01-01T00:00:00Z', {'Content-Type' => 'application/json'})
    assert_equal 200, last_response.status
    resp = JSON.parse(last_response.body)
    assert_equal 2, resp['deleted_ids'].length
    assert_equal 0, resp['objects'].length
    assert_equal '3', resp['deleted_ids'][0]
    assert_equal '4', resp['deleted_ids'][1]
  end

end