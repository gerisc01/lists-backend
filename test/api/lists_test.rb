require_relative '../../src/api/lists_api'
require 'sinatra/base'
require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'
require 'mocha/minitest'

describe Api do
  include Rack::Test::Methods

  def app
    api = Api.new
    ENV["LISTSPRGM_OUTPUT_ERRORS"] = "false"
    return api
  end
  
  before do
    @list1 = List.new("First List")
    @list2 = List.new("Second List")
    @lists_load = {@list1.id => @list1.to_hash, @list2.id => @list2.to_hash}
  end

  after do
    File.delete(List.file_name) if File.exist?(List.file_name)
  end
  
  describe "#list api list" do
    
    it "list | happy path" do
      List.stubs(:load).returns(@lists_load).once
      get '/api/lists'
      assert_equal 200, last_response.status
      assert_equal @lists_load.values.to_json, last_response.body
    end

    it "list | empty path" do
      List.stubs(:load).returns({}).once
      get '/api/lists'
      assert_equal 200, last_response.status
      assert_equal "[]", last_response.body
    end
    
  end

  describe "#list api create" do
      
    it "create | happy path" do
      input = {"name" => @list1.name}
      List.stubs(:create).returns(@list1.to_hash).once
      post('/api/lists', input.to_json, {"Content-Type" => "application/json"})
      puts last_response.errors if last_response.status == 500
      assert_equal 201, last_response.status
      output = JSON.parse(last_response.body)
      assert output["id"] != nil, "Expected id to be populated"
      assert_equal @list1.name, output["name"]
    end

    it "create | bad request | empty" do
      post('/api/lists', "{}", {"Content-Type" => "application/json"})
      puts last_response.errors if last_response.status == 500
      assert_equal 400, last_response.status
      output = JSON.parse(last_response.body)
      assert output["message"] != nil, "Expected error message to be populated"
    end
    
  end

  describe "#list api delete" do
      
    it "delete | happy path" do
      List.stubs(:delete).returns(nil).once
      delete('/api/lists/1')
      puts last_response.errors if last_response.status == 500
      assert_equal 200, last_response.status
      assert_equal "", last_response.body
    end

  end

end