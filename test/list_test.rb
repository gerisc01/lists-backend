require 'minitest/autorun'
require 'minitest/spec'
require './src/list'

describe List do

  before do
    List.file_name = "lists_test.json"
  end

  after do
    File.delete(List.file_name) if File.exist?(List.file_name)
  end
  
  describe "#new" do
    
    it "list new - success" do
      name = "A Name"
      list = List.new(name)

      assert list.id != nil
      assert list.name == name
    end

    it "list new - failure" do
      assert_raises do
        List.new(nil)
      end
    end

  end

  describe "#integration" do
    
    it "list - create, delete" do
      name = "A Name"
      list = List.new(name)
      result = List.create(list)

      id = result["id"]

      assert result != nil
      assert id != nil
      assert List.get(id) != nil

      List.delete(id)
      assert_nil List.get(id)
    end

  end

end