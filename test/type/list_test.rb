require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../helpers'
require_relative '../../src/type/list'
require_relative '../../src/type/template'

class ListTest < Minitest::Test

  def setup
    @template = Template.new
    @template.key = 'test'
    @template.display_name = 'Test'
    @template.fields = {
      'field1' => {:required => true},
      'field2' => {:type => String},
    }

    @list = List.new({'name' => 'Test List'})
  end

  def teardown
  end

  def test_list_add_item_success
    item_json = {
      'name' => 'Successful Item',
      'field1' => 2,
      'field2' => 'anything'
    }
    item = Item.new(item_json)
    @list.add_item(item)
  end

  def test_list_add_item_failure 
    item_json = {
      'name' => 'Successful Item',
      'field2' => 'anything'
    }
    item = Item.new(item_json)
    @list.add_item(item)
  end

end