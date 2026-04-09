require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/collection'
require_relative '../../src/type/day'
require_relative '../../src/type/template'
require_relative '../../src/type/template_types/recurring_date'
require_relative '../../src/storage'

# Separate from DatesApiTest because test data will be slightly different
# while looking similar, so keeping them separate to avoid any confusion.
class DatesRecurringApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end

  def setup
    @item = Item.new({'id' => '1r', 'name' => 'One Recurring'})
    @item2 = Item.new({'id' => '2n', 'name' => 'Two Non Recurring'})
    @collection = Collection.new({'id' => 'a', 'name' => 'A Collection'})
    @template = Template.new(get_recurring_item_template_json())
    [@item, @item2, @collection, @template].each { |obj| obj.save! }

    @day = Day.new({'id' => '2025-01-01', 'items' => [ {'id' => @collection.id, 'items' => [@item.id]} ]})
    @day.save!
    Day.toggle_cache_source(:test)
  end

  def teardown
    Day.clear_cache
    Day.toggle_cache_source(:prod)
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  # Non-Recurring Date => Recurring Date
  def test_create_recurring_item_from_non_recurring
    payload = { "collection": "a", "item": "1r", "interval": 1, "type": "weekly" }.to_json
    post("/api/dates/2025-06-01/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    response = JSON.parse(last_response.body)
    assert_equal '1r', response['id']
    item = Item.get('1r')
    assert_equal ['recurring-item'], item.templates
    assert_equal 1, item.json['recurring-event']['interval']
    assert_equal 'weekly', item.json['recurring-event']['type']
    # Check that children were created
    assert_equal 52, item.json['recurring-children'].length
    # There should only be a single item on the original day
    assert_equal ({'id' => 'a', 'items' => ['1r']}), Day.get('2025-06-01').to_schema_object['items'][0]
    # Spot check a few children exist on the correct days
    assert Day.get('2025-06-08').items.any? { |d| d.id == 'a' && d.items.include?(item.json['recurring-children'][0]) }
    assert Day.get('2025-06-15').items.any? { |d| d.id == 'a' && d.items.include?(item.json['recurring-children'][1]) }
    assert Day.get_days_for_item(item.json['recurring-children'][51]), ["2026-05-31"]
  end

  # No Date => Recurring Date
  def test_create_recurring_item_from_no_date
    payload = { "collection": "a", "item": "2n", "interval": 1, "type": "weekly" }.to_json
    post("/api/dates/2025-01-07/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    response = JSON.parse(last_response.body)
    assert_equal '2n', response['id']

    item = Item.get('2n')
    assert item.templates.include?('recurring-item')
    assert_equal 1, item.json['recurring-event']['interval']
    assert_equal 'weekly', item.json['recurring-event']['type']
    # Check that children were created
    assert_equal 52, item.json['recurring-children'].length
    # Item should still be on the original day
    assert Day.get('2025-01-07').items.any? { |d| d.id == 'a' && d.items.include?('2n') }
    # Spot check children exist on the correct future days
    assert Day.get('2025-01-14').items.any? { |d| d.id == 'a' && d.items.include?(item.json['recurring-children'][0]) }
    assert Day.get('2025-01-21').items.any? { |d| d.id == 'a' && d.items.include?(item.json['recurring-children'][1]) }
  end

  # Recurring Date => Recurring Date
  def test_modify_recurring_item_original
    # Takes too long to set up all the data manually, so just create the recurring item first
    payload = { "collection": "a", "item": "1r", "interval": 1, "type": "weekly" }.to_json
    post("/api/dates/2025-06-01/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    original_item = JSON.parse(last_response.body)
    # Now modify the original recurring item to have a different interval and start date
    payload = { "collection": "a", "item": "1r", "interval": 2, "type": "weekly" }.to_json
    put("/api/dates/2025-06-02/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    response = JSON.parse(last_response.body)
    assert_equal original_item['id'], response['id']
    assert_equal 2, response['recurring-event']['interval']
    assert original_item['recurring-children'].length != response['recurring-children'].length
    # Check that the item itself still exists and the correct children remain
    item = Item.get('1r')
    assert_equal 26, item.json['recurring-children'].length
    # Check that the new days have the children items
    assert_equal ({'id' => 'a', 'items' => ['1r']}), Day.get('2025-06-02').to_schema_object['items'][0]
    assert Day.get('2025-06-16').items.any? { |d| d.id == 'a' && d.items.include?(item.json['recurring-children'][0]) }
    assert Day.get('2025-06-30').items.any? { |d| d.id == 'a' && d.items.include?(item.json['recurring-children'][1]) }
    # Check that the original days have no items
    assert_nil Day.get('2025-06-01')
    assert_nil Day.get('2025-06-08')
  end

  # Recurring Date => Recurring Date
  def test_modify_recurring_item_midway
    # Takes too long to set up all the data manually, so just create the recurring item first
    payload = { "collection": "a", "item": "1r", "interval": 1, "type": "weekly" }.to_json
    post("/api/dates/2025-06-01/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    original_item = JSON.parse(last_response.body)
    # Now modify the 3rd occurrence of the recurring item to have a different interval and start date
    third_occurrence_id = original_item['recurring-children'][2]
    payload = { "collection": "a", "item": third_occurrence_id, "interval": 2, "type": "weekly" }.to_json
    put("/api/dates/2025-06-29/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    response = JSON.parse(last_response.body)
    assert_equal third_occurrence_id, response['id']
    assert_equal 2, response['recurring-event']['interval']
    assert_equal original_item['id'], response['recurring-parent']
    # Check that the parent item still exists and the correct children remain
    parent_item = Item.get(original_item['id'])
    assert_equal 2, parent_item.json['recurring-children'].length
    # Check that the item itself still exists and the correct children remain
    item = Item.get(third_occurrence_id)
    assert_equal 26, item.json['recurring-children'].length
    # Check that the old days still have the children items
    assert_equal ({'id' => 'a', 'items' => ['1r']}), Day.get('2025-06-01').to_schema_object['items'][0]
    assert Day.get('2025-06-08').items.any? { |d| d.id == 'a' && d.items.include?(parent_item.json['recurring-children'][0]) }
    assert Day.get('2025-06-15').items.any? { |d| d.id == 'a' && d.items.include?(parent_item.json['recurring-children'][1]) }
    # Check that the original days have no items
    assert_nil Day.get('2025-06-22')
    assert_nil Day.get('2025-07-06')
    # Check that the new days have the children items
    assert_equal ({'id' => 'a', 'items' => [third_occurrence_id]}), Day.get('2025-06-29').to_schema_object['items'][0]
    assert Day.get('2025-07-13').items.any? { |d| d.id == 'a' && d.items.include?(item.json['recurring-children'][0]) }
  end

  # Recurring Date => No Date
  def test_delete_recurring_item_original
    # Takes too long to set up all the data manually, so just create the recurring item first
    payload = { "collection": "a", "item": "1r", "interval": 1, "type": "weekly" }.to_json
    post("/api/dates/2025-06-01/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    original_item = JSON.parse(last_response.body)
    # Now delete the original recurring item
    payload = { "collection": "a", "item": '1r' }.to_json
    delete("/api/dates/2025-06-01/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    response = JSON.parse(last_response.body)
    assert_equal original_item['id'], response['id']
    # Check that the item itself still exists and the correct children remain
    parent_item = Item.get('1r')
    assert parent_item.json['recurring-children'].nil?
    assert parent_item.json['recurring-event'].nil?
    # Check that no days have the children items
    assert_nil Day.get('2025-06-01')
    assert_nil Day.get('2025-06-08')
  end

  # Recurring Date => Recurring Date
  def test_delete_recurring_item_midway
    # Takes too long to set up all the data manually, so just create the recurring item first
    payload = { "collection": "a", "item": "1r", "interval": 1, "type": "weekly" }.to_json
    post("/api/dates/2025-06-01/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    original_item = JSON.parse(last_response.body)
    # Now delete starting from the 3rd occurrence, don't need a date for recurring children since we can look it up
    payload = { "collection": "a", "item": original_item['recurring-children'][2] }.to_json
    delete("/api/dates/~/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    response = JSON.parse(last_response.body)
    assert_equal original_item['id'], response['id']
    # Check that the item itself still exists and the correct children remain
    parent_item = Item.get('1r')
    assert_equal 2, parent_item.json['recurring-children'].length
    # Check that days after 2025-06-15 no longer have the children items
    assert_nil Day.get('2025-06-22')
    assert_nil Day.get('2025-06-29')
  end

  # Recurring Date => Non-Recurring Date
  def test_modify_recurring_item_to_non_recurring
    # Takes too long to set up all the data manually, so just create the recurring item first
    payload = { "collection": "a", "item": "1r", "interval": 1, "type": "weekly" }.to_json
    post("/api/dates/2025-06-01/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    original_item = JSON.parse(last_response.body)
    # Now delete starting from the first child occurrence, don't need a date for recurring children since we can look it up
    payload = { "collection": "a", "item": original_item['recurring-children'][0] }.to_json
    delete("/api/dates/~/recurring", payload, {"Content-Type" => "application/json"})
    assert_equal 200, last_response.status
    response = JSON.parse(last_response.body)
    assert_equal original_item['id'], response['id']
    # Check that the item itself still exists and the correct children remain
    parent_item = Item.get('1r')
    # TODO: In the future templates should remove the recurring-item template but it doesn't do it yet
    # assert_equal [], parent_item.json['templates']
    assert_nil parent_item.json['recurring-event']
    assert_nil parent_item.json['recurring-children']
  end

  ##################################################################
  # Helper methods for recurring date tests
  ##################################################################
  def get_recurring_item_template_json
    {
      "id" => "recurring-item",
      "key" => "recurring-item",
      "display_name" => "Recurring Item",
      "fields" => [
        {
          "key" => "recurring-event",
          "display_name" => "Recurring Event",
          "type" => "SchemaType::RecurringDate",
          "subtype" => nil,
          "required" => false,
          "type_ref" => nil,
          "no_dups" => nil
        },
        {
          "key" => "recurring-parent",
          "display_name" => "Recurring Parent",
          "type" => "Item",
          "subtype" => nil,
          "required" => false,
          "type_ref" => true,
          "no_dups" => nil
        },
        {
          "key" => "recurring-children",
          "display_name" => "Recurring Children",
          "type" => "Array",
          "subtype" => "String",
          "required" => false,
          "type_ref" => false,
          "no_dups" => nil
        }
      ]
    }
  end

end
