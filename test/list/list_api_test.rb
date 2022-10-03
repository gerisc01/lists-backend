require 'sinatra/base'
require 'minitest/autorun'
require 'mocha/minitest'
require 'rack/test'
require_relative '../../src/list/list_api'
require_relative '../helpers/test_list_db'
require_relative '../../src/list/list'

class ListApiTest < Minitest::Test
  include Rack::Test::Methods

  def app
    api = Api.new
    return api
  end
  
  def setup
    List.set_db_class(TestListDb)
    @list1 = List.from_object({"id" => "1", "name" => "One"})
    @list2 = List.from_object({"id" => "2", "name" => "Two"})
    @lists_loaded = {@list1.id => @list1.to_object, @list2.id => @list2.to_object}
    TestListDb.stubs(:file_load).returns(@lists_loaded)
    TestListDb.stubs(:persist).returns(nil)
  end

  def teardown
    TestListDb.teardown
  end

  ## List tests
    
  def test_list_lists_multiple
    get '/api/lists'
    assert_equal 200, last_response.status
    assert_equal @lists_loaded.values.to_json, last_response.body
  end

  def test_list_lists_empty
    TestListDb.stubs(:file_load).returns({}).once
    get '/api/lists'
    assert_equal 200, last_response.status
    assert_equal "[]", last_response.body
  end
    
  ## List create

  def test_list_create_valid
    input = {"name" => @list1.name}
    post('/api/lists', input.to_json, {"Content-Type" => "application/json"})
    assert_equal 201, last_response.status
    output = JSON.parse(last_response.body)
    assert output["id"] != nil, "Expected id to be populated"
    assert_equal @list1.name, output["name"]
  end

  def test_list_create_badRequest
    post('/api/lists', "{}", {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
    output = JSON.parse(last_response.body)
    assert "Bad Request", output["error"]
    assert output["message"] != nil, "Expected error message to be populated"
  end

  ## List update
      
  def test_list_update_valid
    put('/api/lists/1', {"name" => "Updated"}.to_json, {"Content-Type" => "application/json"})
    expected_update_body = {"id" => @list1.id, "name" => "Updated", "items" => []}.to_json
    assert_equal 200, last_response.status
    assert_equal expected_update_body, last_response.body
  end

  def test_list_update_invalidId
    put('/api/lists/0000', {"name" => "Updated"}.to_json, {"Content-Type" => "application/json"})
    assert_equal 404, last_response.status
    output = JSON.parse(last_response.body)
    assert "Not Found", output["error"]
    assert output["message"] != nil, "Expected error message to be populated"
  end

  def test_list_update_badRequest
    put('/api/lists/1', "", {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
    output = JSON.parse(last_response.body)
    assert "Bad Request", output["error"]
    assert "Invalid JSON", output["type"]
    assert output["message"] != nil, "Expected error message to be populated"
  end

  ## List delete

  def test_list_delete_success
    delete('/api/lists/1')
    puts last_response.errors if last_response.status == 500
    assert_equal 204, last_response.status
    assert_equal "", last_response.body
  end

  def test_list_delete_ignoresInvalidId
    delete('/api/lists/1')
    puts last_response.errors if last_response.status == 500
    assert_equal 204, last_response.status
    assert_equal "", last_response.body
  end

end