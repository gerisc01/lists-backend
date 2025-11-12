require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/list'
require_relative '../../src/storage'

class DatesApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    @list = List.new({'id' => 'a', 'name' => 'list-one', 'items' => ['1', '2']})
    @list2 = List.new({'id' => 'b', 'name' => 'list-two', 'items' => ['1']})
    [@item, @item2, @list, @list2].each { |obj| obj.save! }

    @day = Day.new({'id' => '2025-01-01', 'items' => [ {'id' => @list.id, 'items' => [@item.id, @item2.id]} ]})
    @day.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  # TODO: The following 2 tests should probably live in a day_test.rb file instead of api tests
  def test_create_date_with_items
    payload = {
      'id': '2025-11-11',
      'items': [ { 'id': @list.id, 'items': [ @item.id, @item2.id ] } ]
    }.to_json
    post("/api/dates", payload, {"Content-Type" => "application/json"})
    assert_equal 201, last_response.status
    assert_equal '2025-11-11', JSON.parse(last_response.body)['id']
    assert_equal [@item.id, @item2.id], Day.get('2025-11-11').items.first.items
  end

  def test_create_date_failure_invalid_items
    payload = {
      'id': '2025-11-11',
      'items': [ { 'id': @list.id, 'items': [ 'NOT_FOUND'] } ]
    }.to_json
    post("/api/dates", payload, {"Content-Type" => "application/json"})
    assert_equal 500, last_response.status
    # assert_includes last_response.body, 'NOT_FOUND'
    assert_nil Day.get('2025-11-11')
  end

  def test_get_items_for_date_and_list
    get("/api/dates/#{@day.id}/#{@list.id}/items")
    assert_equal 200, last_response.status
    items = JSON.parse(last_response.body)
    assert_equal [@item.id, @item2.id], items
  end

  def test_get_items_for_empty_date
    get("/api/dates/1970-01-01/#{@list.id}/items")
    assert_equal 200, last_response.status
    items = JSON.parse(last_response.body)
    assert_equal [], items
  end

  def test_get_items_for_empty_list
    get("/api/dates/#{@day.id}/#{@list2.id}/items")
    assert_equal 200, last_response.status
    items = JSON.parse(last_response.body)
    assert_equal [], items
  end

  def test_update_single_priority_item
    payload = [ @item.id ].to_json
    put("/api/dates/#{@day.id}/#{@list.id}/priorities", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    day = JSON.parse(last_response.body)
    assert_equal day['priorities'].length, 1
    assert_equal day['priorities'][0]['id'], @list.id
    assert_equal day['priorities'][0]['items'], [@item.id]
  end

  def test_update_multiple_priority_items
    payload = [ @item.id ].to_json
    put("/api/dates/#{@day.id}/#{@list.id}/priorities", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status

    payload = [ @item.id, @item2.id ].to_json
    put("/api/dates/#{@day.id}/#{@list.id}/priorities", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status

    day = JSON.parse(last_response.body)
    assert_equal day['priorities'].length, 1
    assert_equal day['priorities'][0]['id'], @list.id
    assert_equal day['priorities'][0]['items'], [ @item.id, @item2.id ]
  end

  def test_update_remove_priority_items
    payload = [ @item.id, @item2.id ].to_json
    put("/api/dates/#{@day.id}/#{@list.id}/priorities", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status

    payload = [].to_json
    put("/api/dates/#{@day.id}/#{@list.id}/priorities", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    day = JSON.parse(last_response.body)
    assert_equal day['priorities'].length, 1
    assert_equal day['priorities'][0]['id'], @list.id
    assert_equal day['priorities'][0]['items'], [ ]
  end

end
