require 'sinatra/base'
require 'minitest/autorun'
require 'mocha/minitest'
require 'rack/test'
require_relative '../../src/api/collection_api'
require_relative '../helpers/test_collection_db'
require_relative '../../src/type/collection'

class CollectionApiTest < Minitest::Test
  include Rack::Test::Methods

  def app
    api = Api.new
    return api
  end
  
  def setup
    Collection.set_db_class(TestCollectionDb)
    @collection1 = Collection.from_object({"id" => "1", "name" => "One"})
    @collection2 = Collection.from_object({"id" => "2", "name" => "Two"})
    @collections_loaded = {@collection1.id => @collection1.to_object, @collection2.id => @collection2.to_object}
    TestCollectionDb.stubs(:file_load).returns(@collections_loaded)
    TestCollectionDb.stubs(:persist).returns(nil)
  end

  def teardown
    TestCollectionDb.teardown
  end

  ## Collection tests
    
  def test_collection_lists_multiple
    get '/api/collections'
    assert_equal 200, last_response.status
    assert_equal @collections_loaded.values.to_json, last_response.body
  end

  def test_collection_lists_empty
    TestCollectionDb.stubs(:file_load).returns({}).once
    get '/api/collections'
    assert_equal 200, last_response.status
    assert_equal "[]", last_response.body
  end
    
  ## Collection create

  def test_collection_create_valid
    input = {"name" => @collection1.name}
    post('/api/collections', input.to_json, {"Content-Type" => "application/json"})
    assert_equal 201, last_response.status
    output = JSON.parse(last_response.body)
    assert output["id"] != nil, "Expected id to be populated"
    assert_equal @collection1.name, output["name"]
  end

  def test_collection_create_badRequest
    post('/api/collections', "{}", {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
    output = JSON.parse(last_response.body)
    assert "Bad Request", output["error"]
    assert output["message"] != nil, "Expected error message to be populated"
  end

  ## Collection update
      
  def test_collection_update_valid
    put('/api/collections/1', {"name" => "Updated"}.to_json, {"Content-Type" => "application/json"})
    expected_update_body = {"id" => @collection1.id, "name" => "Updated", "lists" => []}.to_json
    assert_equal expected_update_body, last_response.body
    assert_equal 200, last_response.status
  end

  def test_collection_update_invalidId
    put('/api/collections/0000', {"name" => "Updated"}.to_json, {"Content-Type" => "application/json"})
    assert_equal 404, last_response.status
    output = JSON.parse(last_response.body)
    assert "Not Found", output["error"]
    assert output["message"] != nil, "Expected error message to be populated"
  end

  def test_collection_update_badRequest
    put('/api/collections/1', "", {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
    output = JSON.parse(last_response.body)
    assert "Bad Request", output["error"]
    assert "Invalid JSON", output["type"]
    assert output["message"] != nil, "Expected error message to be populated"
  end

  ## Collection delete

  def test_collection_delete_success
    delete('/api/collections/1')
    puts last_response.errors if last_response.status == 500
    assert_equal 204, last_response.status
    assert_equal "", last_response.body
  end

  def test_collection_delete_ignoresInvalidId
    delete('/api/collections/1')
    puts last_response.errors if last_response.status == 500
    assert_equal 204, last_response.status
    assert_equal "", last_response.body
  end

end