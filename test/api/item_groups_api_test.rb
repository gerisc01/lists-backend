require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'

class ItemGroupsApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end

  def setup
    %w[i1 i2 i3 loose].each { |id| Item.new({'id' => id, 'name' => id}).save! }
    ItemGroup.new({'id' => 'g1', 'name' => 'Yakuza series', 'group' => %w[i1 i2]}).save!
    ItemGroup.new({'id' => 'g2', 'name' => 'Hang the pegboard', 'group' => %w[i3]}).save!
  end

  def teardown
    TypeStorage.clear_test_storage
  end

  def for_members(ids)
    get "/api/itemGroups/forMembers?ids=#{ids}", {}, { 'HTTP_ACCOUNT_ID' => 'a1' }
    JSON.parse(last_response.body)
  end

  # The member -> group lookup the planner needs so a board card can say what bigger
  # thing it is part of. A member carries no back-pointer, so this is the only answer.
  def test_returns_the_group_claiming_a_member
    body = for_members('i2')
    assert_equal 200, last_response.status
    assert_equal ['g1'], body.map { |g| g['id'] }
    assert_equal 'Yakuza series', body.first['name']
  end

  def test_returns_every_group_touched_by_the_id_set
    assert_equal %w[g1 g2], for_members('i1,i3').map { |g| g['id'] }.sort
  end

  # An item in no group is not an error — the planner asks about every staged item at
  # once and expects a partial answer.
  def test_an_item_in_no_group_yields_nothing
    assert_equal [], for_members('loose')
  end

  def test_no_ids_yields_nothing
    assert_equal [], for_members('')
  end

  # The generated CRUD's GET /api/itemGroups/:id would swallow this path as an id if it
  # were declared first, and the failure would be a silent 404 rather than a broken route.
  def test_the_route_is_not_shadowed_by_the_id_read
    get '/api/itemGroups/g1', {}, { 'HTTP_ACCOUNT_ID' => 'a1' }
    assert_equal 'g1', JSON.parse(last_response.body)['id']
    assert_equal 200, last_response.status

    for_members('i1')
    assert_equal 200, last_response.status
  end
end
