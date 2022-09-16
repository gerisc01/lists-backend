require 'minitest/autorun'
require 'minitest/spec'
require './src/list'

describe List do

  def setup
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

  describe "#create" do
    
    it "list create - success" do
      name = "A Name"
      list = List.new(name)
      result = List.create(list)

      assert result != nil
      assert result["id"] != nil
      assert List.get(result["id"]) != nil
    end

  end

end