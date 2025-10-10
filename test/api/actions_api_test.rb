require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/storage'

class ActionsApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end

  def setup
    @item = Item.new({'id' => '1', 'name' => 'One'})
    @item.save!
    @item2 = Item.new({'id' => '2', 'name' => 'Two'})
    @item2.save!
    @group = ItemGroup.new({'id' => 'one', 'name' => 'Group', 'group' => ['2']})
    @list = List.new({'id' => 'a', 'name' => 'list-one', 'items' => ['1', '2']})
    @list.save!
    @list2 = List.new({'id' => 'b', 'name' => 'list-two'})
    @list2.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_ad_hoc_action_success
    payload = {'item_id' => @item.id, 'from_list' => @list.id, 'to_list' => @list2.id}.to_json
    post("/api/actions/ad-hoc/moveItem", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal [@item2.id], @list.items
    assert_equal [@item.id], @list2.items
  end

  def test_move_item_success
    action = move_item_action
    action.save!
    payload = {'item_id' => @item.id, 'from_list' => @list.id}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal [@item2.id], @list.items
    assert_equal [@item.id], @list2.items
  end

  def test_move_item_failure
    action = move_item_action
    action.save!
    payload = {'item_id' => 'NOT_FOUND', 'from_list' => @list.id}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status

    payload = {'item_id' => @item.id, 'from_list' => 'NOT_FOUND'}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
  end

  def test_copy_item_success
    action = copy_item_action
    action.save!
    @list2.add_item(@item)
    payload = {'item_id' => @item2.id, 'from_list' => @list.id}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal [@item.id, @item2.id], @list.items
    assert_equal [@item.id, @item2.id], @list2.items
  end

  def test_copy_item_failure
    action = copy_item_action
    action.save!
    payload = {'item_id' => 'NOT_FOUND'}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
  end

  def test_remove_item_multiple
    action = remove_item_action
    action.save!
    @list.add_item(@item)
    payload = {'item_id' => @item.id, 'from_list' => @list.id}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal [@item2.id], @list.items
  end

  def test_remove_item_by_index
    action = remove_item_action
    action.save!
    @list.add_item(@item)
    payload = {'item_id' => @item.id, 'from_list' => @list.id, 'item_index' => 0}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal [@item2.id, @item.id], @list.items
  end

  def test_remove_item_failure
    action = remove_item_action
    action.save!
    payload = {'item_id' => @item.id, 'from_list' => @list.id, 'item_index' => 1}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status

    payload = {'item_id' => @item.id, 'from_list' => 'NOT_FOUND'}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
  end

  def test_set_field
    action = set_field_action
    action.save!
    payload = {'item_id' => @item.id, 'value' => 'New Name'}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal 'New Name', @item.name
  end

  def test_set_field_failure
    action = set_field_action
    action.save!
    payload = {'item_id' => @item.id, 'value' => 2}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status

    payload = {'item_id' => 'NOT_FOUND', 'value' => 'Other Name'}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 400, last_response.status
  end

  def test_multiple_actions
    action = Action.new({
      'name' => 'Multiple Actions',
      'steps' => [
        move_item_action.steps[0],
        set_field_action.steps[0]
      ],
      'inputs' => {
        'item_id' => 'any',
        'from_list' => 'any',
        'value' => 'any'
      }
    })
    action.save!
    payload = {'item_id' => @item.id, 'from_list' => @list.id, 'value' => 'New Name'}.to_json
    post("/api/actions/#{action.id}", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    assert_equal 'New Name', @item.name
    assert_equal [@item2.id], @list.items
    assert_equal [@item.id], @list2.items
  end

  ########### Helper Methods ###########
  def move_item_action
    Action.new({
      'name' => 'Move Item',
      'steps' => [
        {
          'type' => 'moveItem',
          'fixed_params' => {'to_list' => @list2.id}
        }
      ],
      'inputs' => {
        'item_id' => 'any',
        'from_list' => 'any'
      }
    })
  end

  def copy_item_action
    Action.new({
      'name' => 'Copy Item',
      'steps' => [
       {
         'type' => 'copyItem',
         'fixed_params' => {'to_list' => @list2.id}
       }
      ],
      'inputs' => {
        'item_id' => 'any',
        'from_list' => 'any'
      }
    })
  end

  def remove_item_action
    Action.new({
     'name' => 'Remove Item',
     'steps' => [
       {
         'type' => 'removeItem'
       }
     ],
     'inputs' => {
       'item_id' => 'any',
       'from_list' => 'any',
       'item_index' => 'any'
     }
   })
  end

  def set_field_action
    Action.new({
     'name' => 'Set Field Action',
     'steps' => [
       {
         'type' => 'setField',
         'fixed_params' => {'key' => 'name'}
       }
     ],
     'inputs' => {
       'item_id' => 'any',
       'value' => 'any'
     }
    })
  end

end
