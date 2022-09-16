require_relative '../../src/api/lists.rb'
require 'sinatra/base'
require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'
require 'pry'

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
  
  describe "#list api list" do
    
    it "list | happy path" do
      List.stub :load, @lists_load do
        get '/api/lists'
        assert_equal 200, last_response.status
        assert_equal @lists_load.values.to_json, last_response.body
      end
    end

    it "list | empty path" do
      List.stub :load, {} do
        get '/api/lists'
        assert_equal 200, last_response.status
        assert_equal "[]", last_response.body
      end
    end
    
  end

  describe "#list api create" do
      
    it "create | happy path" do
      List.stub :create, nil do
        input = {"name" => "First List"}
        post('/api/lists', input.to_json, {"Content-Type" => "application/json"})
        puts last_response.errors if last_response.status == 500
        assert_equal 201, last_response.status
        output = JSON.parse(last_response.body)
        assert output["id"] != nil, "Expected id to be populated"
        assert_equal output["name"], "First List"
      end
    end

    it "create | bad request | empty" do
      post('/api/lists', "{}", {"Content-Type" => "application/json"})
      puts last_response.errors if last_response.status == 500
      assert_equal 400, last_response.status
      output = JSON.parse(last_response.body)
      assert output["message"] != nil, "Expected error message to be populated"
    end
    
  end

end