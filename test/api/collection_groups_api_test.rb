require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/collection'
require_relative '../../src/type/collection_group'
require_relative '../../src/type/account'

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
    headers['HTTP_ACCOUNT_ID'] = account_id if !account_id.nil?
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

  def test_sharing_a_group_is_a_write_to_the_group
    as('acct_a', :post, '/api/collection-groups', group_payload)
    as('acct_a', :put, '/api/collection-groups/household',
       group_payload('members' => %w[acct_a acct_b]))

    as('acct_b', :get, '/api/collection-groups')
    assert_equal ['household'], JSON.parse(last_response.body).map { |g| g['id'] }
  end

  # Holding a group grants its one-off collection and nothing else it names.
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
