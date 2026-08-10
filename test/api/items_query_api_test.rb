require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item_group'
require_relative '../../src/query/search'

class ItemsQueryApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end

  def setup
    Tag.new({'id' => 't-me', 'name' => 'Me'}).save!
    Item.new({'id' => 'paint', 'name' => 'Paint the basement',
              'energy' => 'intense', 'tags' => ['t-me']}).save!
    Item.new({'id' => 'switch', 'name' => 'Fix the light switch', 'energy' => 'chill'}).save!
    List.new({'id' => 'projects', 'name' => 'Projects', 'items' => %w[paint switch]}).save!
    Collection.new({'id' => 'home', 'name' => 'Home', 'lists' => %w[projects]}).save!
  end

  def query(q)
    get "/api/items/query?q=#{CGI.escape(q)}"
  end

  def result_ids
    JSON.parse(last_response.body)['groups'].flat_map { |g| g['items'].map { |i| i['id'] } }
  end

  def test_returns_matches_grouped_by_collection
    query('energy = chill')
    assert_equal 200, last_response.status

    payload = JSON.parse(last_response.body)
    assert_equal 1, payload['count']
    assert_equal 'Home', payload['groups'].first['collection_name']
    assert_equal %w[switch], result_ids
  end

  def test_a_full_boolean_expression_round_trips_through_the_url
    query('(energy = chill OR tag = Me) AND NOT name ~ nothing')
    assert_equal 200, last_response.status
    assert_equal %w[paint switch], result_ids.sort
  end

  # The route has to be declared above generate_schema_crud_methods, or the
  # generated GET /api/items/:id swallows it as a lookup for the item "query".
  def test_the_query_route_is_not_shadowed_by_the_generated_item_lookup
    query('energy = chill')
    assert_equal 200, last_response.status
    refute_nil JSON.parse(last_response.body)['groups']
  end

  def test_no_matches_is_an_empty_200_not_a_404
    query('name ~ "definitely not here"')
    assert_equal 200, last_response.status
    assert_equal 0, JSON.parse(last_response.body)['count']
  end

  def test_a_malformed_query_is_a_400_with_a_usable_message
    query('energy = ')
    assert_equal 400, last_response.status
    assert_includes JSON.parse(last_response.body)['message'], 'value'
  end

  def test_an_unknown_field_is_a_400
    query('colour = red')
    assert_equal 400, last_response.status
    assert_includes JSON.parse(last_response.body)['message'], 'colour'
  end

  def test_a_missing_q_is_a_400
    get '/api/items/query'
    assert_equal 400, last_response.status
  end
end
