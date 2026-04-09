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
    @new_item = Item.new({'id' => '3', 'name' => 'Three (Unassigned)'})
    @collection = Collection.new({'id' => 'a', 'name' => 'Collection A'})
    @collection2 = Collection.new({'id' => 'b', 'name' => 'Collection B'})
    [@item, @item2, @new_item, @collection, @collection2].each { |obj| obj.save! }

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

  # No Date => Non-Recurring Date
  def test_create_new_non_recurring_item
    payload = {
      'collection' => @collection.id,
      'item' => @new_item.id
    }.to_json
    post("/api/dates/#{@day.id}/items", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    resp = JSON.parse(last_response.body)
    daily_item = resp['items'].find { |daily_item| daily_item['id'] == @collection.id }
    assert daily_item['items'].include?(@new_item.id)
    get("/api/items/#{@new_item.id}")
    assert_equal 200, last_response.status
    new_date_item = JSON.parse(last_response.body)
    assert_nil new_date_item['templates']
    assert_nil new_date_item['recurring-event']
    assert_nil new_date_item['recurring-children']
  end

  # Non-Recurring Date => No Date
  # Non-Recurring Date => Non-Recurring Date
  def test_change_non_recurring_item_day
    payload = {
      'collection' => @collection.id,
      'item' => @item2.id
    }.to_json
    delete("/api/dates/#{@day.id}/items", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    resp = JSON.parse(last_response.body)
    daily_item = resp['items'].find { |daily_item| daily_item['id'] == @collection.id }
    assert_nil daily_item['items'].find { |id| id == @item2.id }
    # Add the previous date to a new date (2025-01-07)
    post("/api/dates/2025-01-07/items", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    resp = JSON.parse(last_response.body)
    daily_item = resp['items'].find { |daily_item| daily_item['id'] == @collection.id }
    assert daily_item['items'].include?(@item2.id)
    # Check that the item is only referencing the new date
    get("/api/items/#{@item2.id}/dates")
    assert_equal 200, last_response.status
    resp = JSON.parse(last_response.body)
    assert_equal ['2025-01-07'], resp
  end

end
