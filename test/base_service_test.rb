require 'minitest/autorun'
require 'minitest/spec'
require 'json'
require_relative './resources/test_classes'
require_relative '../src/base_service.rb'

describe BaseService do

  def setup
    obj_map = {
      "1" => {
        "id" => "1",
        "name" => "First"
      },
      "2" => {
        "id" => "2",
        "name" => "Second"
      }
    }
    File.write(BaseServiceTest.file_name, obj_map.to_json)
  end

  def teardown
    BaseServiceTest.teardown
    GenericTestObj.teardown
  end

  describe "#get" do
    
    it "get - success" do
      item = BaseServiceTest.get("2")
      assert_equal "2", item["id"]
      assert_equal "Second", item["name"]
    end

    it "get - missing" do
      item = BaseServiceTest.get("3")
      assert_nil item
    end

  end

  describe "#list" do

    it "list - success" do
      items = BaseServiceTest.list
      assert_equal 2, items.size
      assert_equal ["1", "2"], items.collect{ |it| it["id"] }.sort
    end

  end

  describe "#create" do

    it "create - success" do
      third = BaseServiceTest.new("3", "Third")
      BaseServiceTest.create(third)
      assert_equal 3, BaseServiceTest.get_loaded.size
      assert BaseServiceTest.get_loaded.include?("3")
      
      item = BaseServiceTest.get_loaded["3"]
      assert_equal "3", item["id"]
      assert_equal "Third", item["name"]
    end

    it "create - success, no crossover between classes" do
      base_item = BaseServiceTest.new("3", "Third")
      BaseServiceTest.create(base_item)
      generic_item = GenericTestObj.new("4", "Fourth")
      GenericTestObj.create(generic_item)

      assert_equal 3, BaseServiceTest.get_loaded.size
      assert_equal 1, GenericTestObj.get_loaded.size
    end

    it "create - success, response provided" do
      item = BaseServiceTest.create(BaseServiceTest.new("3", "Third"))
      assert_equal "3", item["id"]
      assert_equal "Third", item["name"]
    end

    it "create - failure, empty id" do
      third = BaseServiceTest.new(nil, "Third")
      assert_raises do
        BaseServiceTest.create(third)
      end
    end

    it "create - failure, duplicate id" do
      item = BaseServiceTest.new("1", "First")
      assert_raises do
        BaseServiceTest.create(item)
      end
    end

    it "create - failure, wrong type" do
      generic_obj = GenericTestObj.new("5", "Five")
      assert_raises do
        BaseServiceTest.create(generic_obj)
      end
    end

  end

  describe "#full integration" do

    it "create | get | list integration test" do
      item = BaseServiceTest.get("10")
      assert_nil item

      BaseServiceTest.create(BaseServiceTest.new("10", "Ten"))
      item = BaseServiceTest.get("10")
      assert_equal "Ten", item["name"]

      item_list = BaseServiceTest.list
      assert_includes item_list, item
    end


  end

end