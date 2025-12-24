require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/storage'

class DatesApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    @collection = Collection.new({'id' => 'a', 'name' => 'Collection A'})
    @collection2 = Collection.new({'id' => 'b', 'name' => 'Collection B'})
    [@item, @item2, @collection, @collection2].each { |obj| obj.save! }

    @day = Day.new({'id' => '2025-01-01', 'items' => [ {'id' => @collection.id, 'items' => [@item.id, @item2.id]} ]})
    @day.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_get_items_for_date_and_collection
    get("/api/dates/#{@day.id}/#{@collection.id}/items")
    assert_equal 200, last_response.status
    items = JSON.parse(last_response.body)
    assert_equal [@item.id, @item2.id], items
  end

  def test_get_items_for_empty_date
    get("/api/dates/1970-01-01/#{@collection.id}/items")
    assert_equal 200, last_response.status
    items = JSON.parse(last_response.body)
    assert_equal [], items
  end

  def test_get_items_for_empty_collection
    get("/api/dates/#{@day.id}/#{@collection2.id}/items")
    assert_equal 200, last_response.status
    items = JSON.parse(last_response.body)
    assert_equal [], items
  end

  def test_update_single_priority_item
    payload = [ @item.id ].to_json
    put("/api/dates/#{@day.id}/#{@collection.id}/priorities", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    day = JSON.parse(last_response.body)
    assert_equal day['priorities'].length, 1
    assert_equal day['priorities'][0]['id'], @collection.id
    assert_equal day['priorities'][0]['items'], [@item.id]
  end

  def test_update_multiple_priority_items
    payload = [ @item.id ].to_json
    put("/api/dates/#{@day.id}/#{@collection.id}/priorities", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status

    payload = [ @item.id, @item2.id ].to_json
    put("/api/dates/#{@day.id}/#{@collection.id}/priorities", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status

    day = JSON.parse(last_response.body)
    assert_equal day['priorities'].length, 1
    assert_equal day['priorities'][0]['id'], @collection.id
    assert_equal day['priorities'][0]['items'], [ @item.id, @item2.id ]
  end

  def test_update_remove_priority_items
    payload = [ @item.id, @item2.id ].to_json
    put("/api/dates/#{@day.id}/#{@collection.id}/priorities", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status

    payload = [].to_json
    put("/api/dates/#{@day.id}/#{@collection.id}/priorities", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    day = JSON.parse(last_response.body)
    assert_equal day['priorities'].length, 1
    assert_equal day['priorities'][0]['id'], @collection.id
    assert_equal day['priorities'][0]['items'], [ ]
  end

end
