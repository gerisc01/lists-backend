require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/collection'
require_relative '../../src/type/collection_group'
require_relative '../../src/type/account'

# The board, as the backend sees it (0085): a named ordered set of collection refs with
# its own membership. Nothing here knows it is a planner.
class CollectionGroupsApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end

  def setup
    %w[acct_a acct_b].each { |id| Account.new({'id' => id, 'name' => id}).save! }
    %w[games projects pad].each { |id| Collection.new({'id' => id, 'name' => id, 'members' => ['acct_a']}).save! }
  end

  def as(account_id, verb, path, payload = nil)
    headers = { 'Content-Type' => 'application/json' }
    headers['HTTP_ACCOUNT_ID'] = account_id unless account_id.nil?
    send(verb, path, payload&.to_json, headers)
  end

  def group_payload(overrides = {})
    { 'id' => 'household', 'name' => 'Household', 'collections' => %w[games projects],
      'members' => ['acct_a'], 'one_off_collection' => 'pad' }.merge(overrides)
  end

  def test_a_group_round_trips
    as('acct_a', :post, '/api/collection-groups', group_payload)
    assert_equal 201, last_response.status

    as('acct_a', :get, '/api/collection-groups/household')
    group = JSON.parse(last_response.body)
    assert_equal %w[games projects], group['collections']
    assert_equal 'pad', group['one_off_collection']
  end

  # Order is the on-screen order of the pile groups, so it is data, not a set.
  def test_collection_order_is_preserved
    as('acct_a', :post, '/api/collection-groups', group_payload('collections' => %w[projects games]))
    as('acct_a', :get, '/api/collection-groups/household')
    assert_equal %w[projects games], JSON.parse(last_response.body)['collections']
  end

  def test_list_returns_only_groups_you_are_a_member_of
    as('acct_a', :post, '/api/collection-groups', group_payload)
    as('acct_a', :post, '/api/collection-groups',
       group_payload('id' => 'work', 'name' => 'Work', 'members' => ['acct_b']))

    as('acct_a', :get, '/api/collection-groups')
    assert_equal ['household'], JSON.parse(last_response.body).map { |g| g['id'] }

    as('acct_b', :get, '/api/collection-groups')
    assert_equal ['work'], JSON.parse(last_response.body).map { |g| g['id'] }
  end

  # Sharing is one write, to the thing being shared (0087).
  def test_sharing_a_group_is_a_write_to_the_group
    as('acct_a', :post, '/api/collection-groups', group_payload)
    as('acct_a', :put, '/api/collection-groups/household',
       group_payload('members' => %w[acct_a acct_b]))

    as('acct_b', :get, '/api/collection-groups')
    assert_equal ['household'], JSON.parse(last_response.body).map { |g| g['id'] }
  end

  # The lens grants nothing. B holds the group and still cannot see the collections it
  # NAMES — the client renders those as "no access" rows rather than dropping them
  # silently. Its one-off collection is the single exception (0085, 0090): that one has no
  # life apart from the group, so holding the group is the only way anyone reaches it.
  def test_holding_a_group_grants_only_its_one_off_collection
    as('acct_a', :post, '/api/collection-groups', group_payload('members' => %w[acct_a acct_b]))

    as('acct_b', :get, '/api/collections')
    assert_equal ['pad'], JSON.parse(last_response.body).map { |c| c['id'] }
  end

  def test_a_group_naming_no_collection_is_rejected
    as('acct_a', :post, '/api/collection-groups', group_payload('collections' => ['nope']))
    refute last_response.ok?
  end
end
