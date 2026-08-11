require_relative '../minitest_wrapper'
# ItemGeneric resolves ItemGroup lazily, so saving a List needs it already loaded.
require_relative '../../src/type/item_group'
require_relative '../../src/query/search'

# End-to-end over real stored objects: collections -> lists -> items, with tags
# resolved by name across collections.
class QuerySearchTest < MinitestWrapper

  def setup
    # Two collections, so cross-collection behavior is actually exercised.
    Tag.new({'id' => 'tag-me-home', 'name' => 'Me'}).save!
    Tag.new({'id' => 'tag-me-food', 'name' => 'Me'}).save!   # same label, different id
    Tag.new({'id' => 'tag-partner', 'name' => 'Partner'}).save!

    Item.new({'id' => 'paint', 'name' => 'Paint the basement',
              'status' => 'want-to', 'energy' => 'intense', 'tags' => ['tag-me-home']}).save!
    Item.new({'id' => 'switch', 'name' => 'Fix the light switch',
              'status' => 'doing', 'energy' => 'chill', 'tags' => ['tag-partner']}).save!
    Item.new({'id' => 'gutters', 'name' => 'Clean the gutters',
              'status' => 'completed'}).save!                 # no energy => moderate, no tags
    Item.new({'id' => 'tacos', 'name' => 'Tacos',
              'status' => 'want-to', 'energy' => 'chill', 'tags' => ['tag-me-food']}).save!

    List.new({'id' => 'projects', 'name' => 'Projects',
              'items' => %w[paint switch gutters]}).save!
    List.new({'id' => 'recipes', 'name' => 'Recipes', 'items' => %w[tacos]}).save!

    Collection.new({'id' => 'home', 'name' => 'Home', 'lists' => %w[projects]}).save!
    Collection.new({'id' => 'food', 'name' => 'Food', 'lists' => %w[recipes]}).save!
  end

  def ids(query)
    Query::Search.run(query)['groups'].flat_map { |g| g['items'].map { |i| i['id'] } }.sort
  end

  def test_matches_across_collections
    assert_equal %w[switch tacos], ids('energy = chill')
  end

  # The reason the moderate default is never persisted: unrated items must answer
  # to `energy = moderate`.
  def test_unrated_items_match_moderate
    assert_equal %w[gutters], ids('energy = moderate')
  end

  def test_name_contains_is_case_insensitive
    assert_equal %w[switch], ids('name ~ "LIGHT SWITCH"')
  end

  # Tags are per-collection ids sharing a label; matching by name is what makes
  # "what's assigned to me" one question instead of one per collection.
  def test_tag_matches_by_name_across_collections
    assert_equal %w[paint tacos], ids('tag = Me')
  end

  # `!=` on a multi-valued field is the negation of `=`: "has no tag named Me",
  # not "has some other tag". `switch` is tagged Partner and still matches; the
  # two Me-tagged items in *different* collections both drop out.
  def test_tag_not_equals_means_does_not_have_that_tag
    assert_equal %w[gutters switch], ids('tag != Me')
  end

  def test_tag_is_empty_finds_untagged_items
    assert_equal %w[gutters], ids('tag IS EMPTY')
  end

  def test_and_or_and_not_compose
    assert_equal %w[paint switch], ids('collection = Home AND status != completed')
    assert_equal %w[switch tacos], ids('energy = chill OR name ~ tacos')
    assert_equal %w[gutters paint], ids('collection = Home AND NOT status = doing')
  end

  # The bug the old regex filter had: a left-to-right fold would return the wrong
  # set here.
  def test_precedence_matches_and_before_or
    # tacos (chill AND food) + paint (want-to)
    assert_equal %w[paint tacos], ids('status = want-to OR energy = chill AND collection = Food')
  end

  def test_parens_override_precedence
    # (want-to OR chill) AND Food => tacos only
    assert_equal %w[tacos], ids('(status = want-to OR energy = chill) AND collection = Food')
  end

  def test_in_list
    assert_equal %w[paint switch tacos], ids('status IN (want-to, doing)')
  end

  def test_collection_and_list_scoping
    assert_equal %w[tacos], ids('collection = Food')
    assert_equal %w[gutters paint switch], ids('list = Projects')
  end

  def test_results_are_grouped_by_collection_and_sorted
    results = Query::Search.run('status IN (want-to, doing)')
    assert_equal 3, results['count']
    assert_equal %w[Food Home], results['groups'].map { |g| g['collection_name'] }
    home = results['groups'].find { |g| g['collection_name'] == 'Home' }
    assert_equal ['Fix the light switch', 'Paint the basement'], home['items'].map { |i| i['name'] }
    assert_equal [{ 'id' => 'projects', 'name' => 'Projects' }], home['items'].first['lists']
  end

  def test_no_matches_is_an_empty_result_not_an_error
    results = Query::Search.run('name ~ "nothing here"')
    assert_equal 0, results['count']
    assert_equal [], results['groups']
  end

  # A typo'd enum must fail loudly — silently returning nothing is the worst
  # outcome for a tool whose job is finding things you can't find.
  def test_invalid_enum_value_is_rejected
    error = assert_raises(ListError::BadRequest) { Query::Search.run('status = doig') }
    assert_includes error.message, 'doig'
    assert_includes error.message, 'want-to'
  end

  def test_invalid_energy_value_is_rejected
    assert_raises(ListError::BadRequest) { Query::Search.run('energy = exhausting') }
  end

  def test_deleted_items_are_excluded
    Item.new({'id' => 'gone', 'name' => 'Deleted thing', 'energy' => 'chill'}).save!
    List.get('projects').json['items'] << 'gone'
    List.get('projects').save!
    assert_includes ids('energy = chill'), 'gone'

    item = Item.get('gone')
    item.json['deleted'] = true
    item.save!
    refute_includes ids('energy = chill'), 'gone'
  end

  # Group children are ordinary items and just as losable as their parent.
  def test_group_children_are_indexed_under_the_parents_location
    Item.new({'id' => 'child', 'name' => 'Sand the walls', 'energy' => 'intense'}).save!
    parent = Item.get('paint')
    parent.json['children'] = ['child']
    parent.save!

    results = Query::Search.run('name ~ sand')
    assert_equal 1, results['count']
    assert_equal 'Home', results['groups'].first['collection_name']
  end

end
