require 'minitest/autorun'
require 'minitest/spec'
require './src/list'

describe List do

  def setup
  end
  
  describe "#create" do
    
    it "list create - success" do
      name = "A Name"
      list = List.new(name)

      assert list.id != nil
      assert list.name == name
    end

    it "list create - failure" do
      assert_raises do
        List.new(nil)
      end
    end

  end

end