require 'sinatra/base'
require_relative '../minitest_wrapper'
require 'rack/test'
require_relative '../test-api'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/storage'
require_relative '../../src/type/account'
require_relative '../../src/type/collection_group'

class CollectionsApiTest < MinitestWrapper
  include Rack::Test::Methods

  def app
    Api.new
  end

  def setup
    @template = Template.new({'id' => 'i', 'key' => 'k1', 'display_name' => 'd1', 'fields' => [{ 'key' => 'name', 'display_name' => 'Name', 'type' => 'String'}]})
    @template2 = Template.new({'id' => 'j', 'key' => 'k2', 'display_name' => 'd2', 'fields' => [{ 'key' => 'name', 'display_name' => 'Name', 'type' => 'String'}]})
    [ @template, @template2 ].each { |t| t.save! }
    @action = Action.new({'id' => 'x', 'name' => 'a1', 'steps' => [{ 'type' => 'moveItem', 'fixed_params' => {}, 'input_params' => []}]})
    @action2 = Action.new({'id' => 'y', 'name' => 'a2', 'steps' => [{ 'type' => 'moveItem', 'fixed_params' => {}, 'input_params' => []}]})
    [ @action, @action2 ].each { |t| t.save! }
    @tag = Tag.new({'id' => 't1', 'name' => 'Tag1', 'color' => '#0000FF'})
    @tag2 = Tag.new({'id' => 't2', 'name' => 'Tag2', 'color' => '#0000FF'})
    [ @tag, @tag2 ].each { |t| t.save! }
    @item = Item.new({'id' => '1', 'name' => 'One', 'tags' => ['t1', 't2']})
    @item2 = Item.new({'id' => '2', 'name' => 'Two', 'tags' => ['t1']})
    [ @item, @item2 ].each { |i| i.save! }
    @list = List.new({'id' => 'a', 'name' => 'Uno', 'actions' => ['x', 'y'], 'items' => []})
    @list2 = List.new({'id' => 'b', 'name' => 'Dos', 'template' => 'i', 'actions' => ['x'], 'items' => []})
    @list2.add_item_with_template_ref(@item)
    @list2.add_item_with_template_ref(@item2)
    @list3 = List.new({'id' => 'c', 'name' => 'Tres', 'template' => 'j', 'items' => []})
    @list3.add_item_with_template_ref(@item)
    [ @list, @list2, @list3 ].each { |l| l.save! }
    @collection = Collection.new({'id' => 'col', 'name' => 'Test', 'lists' => ['a', 'b', 'c'], 'templates' => ['i', 'j'],
       'actions' => ['x','y'], 'tags' => ['t1','t2'], 'groups' => [{'key' => 'g1', 'name' => 'Group 1', 'lists' => ['a', 'b'], 'actions' => ['y']}]})
    @collection.save!
    @collection2 = Collection.new({'id' => 'col2', 'name' => 'Test 2', 'lists' => ['a']})
    @collection2.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_remove_template
    assert_equal ['i', 'j'], @item.templates
    delete("/api/collections/col/templates/i")
    assert_equal ['j'], @item.templates
    assert_equal [], @item2.templates
    assert_nil @list2.template
    assert_equal 'j', @list3.template
  end

  def test_remove_template_cascades_to_itemgroup_members
    gm = Item.new({'id' => 'gm1', 'name' => 'Group Member', 'templates' => ['i']})
    gm.save!
    group = ItemGroup.new({'id' => 'ig1', 'name' => 'Test Group', 'group' => ['gm1']})
    group.save!
    @list2.add_item(group)
    @list2.save!

    delete("/api/collections/col/templates/i")
    refute_includes gm.templates.to_a, 'i'
  end

  def test_remove_template_minimal_collection
    delete("/api/collections/col2/templates/i")
    assert_nil @collection2.actions
  end

  def test_remove_action_list
    assert_equal ['x', 'y'], @list.actions
    delete("/api/collections/col/actions/x")
    assert_equal ['y'], @list.actions
    assert_equal [], @list2.actions
    assert_nil @list3.actions
    assert_equal ['y'], @collection.actions
  end

  def test_remove_action_list_group
    assert_equal ['y'], @collection.json['groups'][0]['actions']
    delete("/api/collections/col/actions/y")
    assert_equal [], @collection.json['groups'][0]['actions']
    assert_equal ['x'], @collection.actions
  end

  def test_remove_action_minimal_collection
    delete("/api/collections/col2/actions/y")
    assert_nil @collection2.actions
  end

  def test_delete_tag_both_matching
    assert_equal ['t1', 't2'], @item.tags
    assert_equal ['t1'], @item2.tags
    delete("/api/collections/col/tags/t1")
    assert_equal ['t2'], @item.tags
    assert_equal [], @item2.tags
    assert_equal ['t2'], @collection.tags
  end

  def test_delete_tag_one_matching
    assert_equal ['t1', 't2'], @item.tags
    assert_equal ['t1'], @item2.tags
    delete("/api/collections/col/tags/t2")
    assert_equal ['t1'], @item.tags
    assert_equal ['t1'], @item2.tags
    assert_equal ['t1'], @collection.tags
  end

  def test_remove_tag_item_group
    group = ItemGroup.new({'id' => 'g1', 'name' => 'Group 1', 'group' => ['1', '2']})
    group.save!

    assert_equal ['t1', 't2'], @item.tags
    assert_equal ['t1'], @item2.tags
    delete("/api/collections/col/tags/t1")
    assert_equal ['t2'], @item.tags
    assert_equal [], @item2.tags
    assert_equal ['t2'], @collection.tags
  end

  def test_remove_tag_minimal_collection
    delete("/api/collections/col2/tags/t1")
    assert_nil @collection2.tags
  end
  # The list read is where membership is enforced (0087) — the client no longer filters,
  # so anything this returns is something you hold.
  def test_list_returns_only_collections_you_are_a_member_of
    Account.new({'id' => 'acct_a', 'name' => 'A'}).save!
    Account.new({'id' => 'acct_b', 'name' => 'B'}).save!
    Collection.new({'id' => 'mine', 'name' => 'Mine', 'members' => ['acct_a']}).save!
    Collection.new({'id' => 'theirs', 'name' => 'Theirs', 'members' => ['acct_b']}).save!

    get('/api/collections', nil, { 'HTTP_ACCOUNT_ID' => 'acct_a' })
    ids = JSON.parse(last_response.body).map { |c| c['id'] }
    assert_includes ids, 'mine'
    refute_includes ids, 'theirs'
  end

  # Sharing is one write to the collection, not a write to someone else's account.
  def test_adding_a_member_is_what_shares_a_collection
    Account.new({'id' => 'acct_b', 'name' => 'B'}).save!
    Collection.new({'id' => 'mine', 'name' => 'Mine', 'members' => []}).save!

    put('/api/collections/mine', { 'members' => ['acct_b'] }.to_json,
        { 'Content-Type' => 'application/json' })

    get('/api/collections', nil, { 'HTTP_ACCOUNT_ID' => 'acct_b' })
    assert_includes JSON.parse(last_response.body).map { |c| c['id'] }, 'mine'
  end

  # An unauthenticated path (the e2e harness) sees the store it just wrote; `protected!`
  # makes that unreachable in production.
  def test_no_account_header_is_unscoped
    Account.new({'id' => 'acct_a', 'name' => 'A'}).save!
    Collection.new({'id' => 'mine', 'name' => 'Mine', 'members' => ['acct_a']}).save!
    get('/api/collections')
    assert_includes JSON.parse(last_response.body).map { |c| c['id'] }, 'mine'
  end

  # A one-off collection carries no roster of its own; the board it belongs to is what
  # grants it (0090). Both halves matter: the member reaches it, and holding no board
  # still reaches nothing.
  def test_a_boards_one_off_collection_is_granted_through_the_board
    Account.new({'id' => 'acct_a', 'name' => 'A'}).save!
    Account.new({'id' => 'acct_b', 'name' => 'B'}).save!
    Collection.new({'id' => 'oneoffs', 'name' => 'Home one-offs', 'members' => []}).save!
    CollectionGroup.new({'id' => 'home', 'name' => 'Home', 'members' => ['acct_a'],
                         'one_off_collection' => 'oneoffs'}).save!

    get('/api/collections', nil, { 'HTTP_ACCOUNT_ID' => 'acct_a' })
    assert_includes JSON.parse(last_response.body).map { |c| c['id'] }, 'oneoffs'

    get('/api/collections', nil, { 'HTTP_ACCOUNT_ID' => 'acct_b' })
    refute_includes JSON.parse(last_response.body).map { |c| c['id'] }, 'oneoffs'
  end

  # Sharing the board is what shares its one-offs — the collection itself is never
  # written. This is the case the roster-copy approach would have gotten wrong.
  def test_sharing_a_board_grants_its_one_off_collection
    Account.new({'id' => 'acct_a', 'name' => 'A'}).save!
    Account.new({'id' => 'acct_b', 'name' => 'B'}).save!
    Collection.new({'id' => 'oneoffs', 'name' => 'Home one-offs', 'members' => []}).save!
    CollectionGroup.new({'id' => 'home', 'name' => 'Home', 'members' => ['acct_a'],
                         'one_off_collection' => 'oneoffs'}).save!

    put('/api/collection-groups/home', { 'members' => ['acct_a', 'acct_b'] }.to_json,
        { 'Content-Type' => 'application/json' })

    get('/api/collections', nil, { 'HTTP_ACCOUNT_ID' => 'acct_b' })
    assert_includes JSON.parse(last_response.body).map { |c| c['id'] }, 'oneoffs'
  end

  def test_a_member_naming_no_account_is_rejected
    Collection.new({'id' => 'mine', 'name' => 'Mine'}).save!
    put('/api/collections/mine', { 'members' => ['ghost'] }.to_json,
        { 'Content-Type' => 'application/json' })
    refute last_response.ok?
  end

end
