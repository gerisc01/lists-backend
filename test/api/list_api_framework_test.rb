require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../../src/api/helpers/list_api_framework'

# class ListApiFrameworkTest < Minitest::Test
class ListApiFrameworkTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    api = TestSinatraApp.new
    return api
  end
  
  def setup
    @items = {
      '1' => ListApiFrameworkTest::GenericClass.new({'id' => '1', 'name' => 'One'}),
      '2' => ListApiFrameworkTest::GenericClass.new({'id' => '2', 'name' => 'Two'})
    }
    @objs = {
      '1' => @items['1'].json,
      '2' => @items['2'].json
    }
  end

  def teardown
    mocha_teardown
  end

  # create
  def test_create_success
    ListApiFrameworkTest::GenericClass.stubs(:new).with(@objs['1']).returns(@items['1']).once
    @items['1'].stubs(:validate).returns(nil).once
    @items['1'].stubs(:save!).returns(nil).once
    post('/api/objects', @objs['1'].to_json, {"Content-Type" => "application/json"})
    assert_equal 201, last_response.status
    assert_equal @objs['1'].to_json, last_response.body
  end

  def test_create_validation_fail
    ListApiFrameworkTest::GenericClass.stubs(:new).with(@objs['1']).returns(@items['1']).once
    @items['1'].stubs(:validate).raises(ListError::Validation).once
    @items['1'].stubs(:save!).returns(nil).never
    post('/api/objects', @objs['1'].to_json, {"Content-Type" => "application/json"})
    assert last_response.status != 201  end

  # get
  def test_get_success
    ListApiFrameworkTest::GenericClass.stubs(:get).with('1').returns(@items['1']).once
    get '/api/objects/1'
    assert_equal 200, last_response.status
    assert_equal @objs['1'].to_json, last_response.body
  end

  def test_get_empty
    ListApiFrameworkTest::GenericClass.stubs(:get).returns(nil).once
    get '/api/objects/3'
    assert_equal 404, last_response.status
    assert_equal "", last_response.body
  end

  # list
  def test_list_success
    ListApiFrameworkTest::GenericClass.stubs(:list).returns(@items.values).once
    get '/api/objects'
    assert_equal 200, last_response.status
    assert_equal @objs.values.to_json, last_response.body
  end

  def test_list_empty
    ListApiFrameworkTest::GenericClass.stubs(:list).returns([]).once
    get '/api/objects'
    assert_equal 200, last_response.status
    assert_equal [].to_json, last_response.body
  end

  # update
  def test_update_success
    updated_input = {'name' => 'New Name'}
    ListApiFrameworkTest::GenericClass.stubs(:get).with('1').returns(@items['1']).once
    @items['1'].stubs(:merge!).returns(nil).once
    @items['1'].stubs(:validate).returns(nil).once
    @items['1'].stubs(:save!).returns(nil).once
    put('/api/objects/1', updated_input.to_json, {"Content-Type" => "application/json"})
    # For this test, the output will match the input because we aren't
    # actually changing the input, just that the proper methods were called
    assert_equal 200, last_response.status
    assert_equal @objs['1'].to_json, last_response.body
  end

  def test_update_validation_fail
    updated_input = {'name' => 'New Name'}
    ListApiFrameworkTest::GenericClass.stubs(:get).with('1').returns(@items['1']).once
    @items['1'].stubs(:merge!).returns(nil).once
    @items['1'].stubs(:validate).raises(ListError::Validation).once
    @items['1'].stubs(:save!).returns(nil).never
    put('/api/objects/1', updated_input.to_json, {"Content-Type" => "application/json"})
    assert last_response.status != 200
  end

  # delete
  def test_delete_success
    ListApiFrameworkTest::GenericClass.stubs(:get).with('1').returns(@items['1']).once
    @items['1'].stubs(:delete!).returns(nil).once
    delete '/api/objects/1'
    assert_equal 204, last_response.status
  end

  def test_delete_empty
    ListApiFrameworkTest::GenericClass.stubs(:get).with('1').returns(nil).once
    @items['1'].stubs(:delete!).returns(nil).never
    delete '/api/objects/1'
    assert_equal 204, last_response.status
  end

  class GenericClass
    attr_accessor :json

    def initialize(json = nil)
      @json = json
    end

    def to_schema_object
      return @json
    end
  end

  class TestSinatraApp < Sinatra::Base
    register Sinatra::ListApiFramework

    generate_schema_crud_methods 'objects', ListApiFrameworkTest::GenericClass
  end

end