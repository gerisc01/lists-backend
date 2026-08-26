require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/list'
require_relative '../../src/type/collection'
require_relative '../../src/actions/create_floating_placement'
require_relative '../../src/actions/assign_to_date'
require_relative '../../src/actions/update_placement'
require_relative '../../src/actions/close_instance'
require_relative '../../src/actions/create_instance'
require_relative '../../src/actions/set_status'

# The whole V1 loop, end to end: stage a game, play sessions, finish it, play it again.
class InstanceLoopTest < MinitestWrapper

  def setup
    @child_template = Template.new
    @child_template.id = 'playthrough'
    @child_template.key = 'playthrough'
    @child_template.display_name = 'Playthrough'
    @child_template.fields = [
      {:key => 'name', :type => String, :required => true},
      {:key => 'started', :type => SchemaType::Date},
      {:key => 'finished', :type => SchemaType::Date},
    ]
    @child_template.save!

    @game_template = Template.new
    @game_template.id = 'game'
    @game_template.key = 'game'
    @game_template.display_name = 'Game'
    @game_template.fields = [{:key => 'name', :type => String, :required => true}]
    @game_template.attributes = {'instances' => {'template' => 'playthrough'}}
    @game_template.save!

    @game = Item.new({'id' => 'kh', 'name' => 'Kingdom Hearts', 'templates' => ['game']})
    @game.save!
    @collection = Collection.new({'id' => 'c1', 'name' => 'Games'})
    @collection.save!
    # A shelf home: this is a catalog item, not a board-born one-off.
    @list = List.new({'id' => 'l1', 'name' => 'Playing', 'items' => ['kh']})
    @list.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_staging_points_the_placement_at_an_instance
    placement = create_floating_placement('kh', 'c1', '2026-08-17')

    refute_equal 'kh', placement.item_id
    assert_equal 'kh', Item.get(placement.item_id).parent
  end

  # The identity a card renders from. Without this the pile shows an instance's name and
  # buckets it as a one-off, because the instance itself has no list home.
  def test_catalog_item_id_resolves_back_to_the_game
    placement = create_floating_placement('kh', 'c1', '2026-08-17')

    assert_equal 'kh', placement.catalog_item_id
    assert_equal 'kh', placement.to_client_object['catalog_item_id']
    assert item_has_shelf_home?(placement.catalog_item_id)
  end

  def test_re_staging_reuses_the_same_instance
    first = create_floating_placement('kh', 'c1', '2026-08-17')
    second = create_floating_placement('kh', 'c1', '2026-08-24')

    assert_equal first.id, second.id
    assert_equal 1, Item.get('kh').children.length
  end

  # Opened is not started: staging alone must not claim you have begun playing.
  def test_staging_does_not_start_the_instance
    placement = create_floating_placement('kh', 'c1', '2026-08-17')

    assert_nil Item.get(placement.item_id).json['started']
    assert_equal 'want-to', Item.get('kh').json['status']
  end

  def test_first_completed_session_starts_the_instance
    placement = assign_to_date('kh', '2026-08-18', 'c1')
    update_placement(placement.id, {'resolution' => 'completed'})

    assert_equal '2026-08-18', Item.get(placement.item_id).json['started']
    assert_equal 'doing', Item.get(placement.item_id).json['status']
    assert_equal 'doing', Item.get('kh').json['status']
  end

  # A fourteen-session playthrough must not close itself on Tuesday of week one.
  def test_a_completed_session_does_not_close_the_instance
    placement = assign_to_date('kh', '2026-08-18', 'c1')
    update_placement(placement.id, {'resolution' => 'completed'})

    refute Status.done?(Item.get(placement.item_id).json['status'])
    assert_equal 'doing', Item.get('kh').json['status']
  end

  def test_closing_finishes_the_instance_and_the_game
    placement = assign_to_date('kh', '2026-08-18', 'c1')
    update_placement(placement.id, {'resolution' => 'completed'})

    close_instance(placement.item_id, '2026-08-30')

    assert_equal '2026-08-30', Item.get(placement.item_id).json['finished']
    assert_equal 'completed', Item.get(placement.item_id).json['status']
    assert_equal 'completed', Item.get('kh').json['status']
  end

  # The replay path, begun with no declared intent beyond staging it again.
  def test_staging_after_a_close_mints_a_second_instance
    first = assign_to_date('kh', '2026-08-18', 'c1')
    update_placement(first.id, {'resolution' => 'completed'})
    close_instance(first.item_id, '2026-08-30')

    second = create_floating_placement('kh', 'c1', '2028-01-03')

    refute_equal first.item_id, second.item_id
    assert_equal 2, Item.get('kh').children.length
    assert_equal 'completed', Item.get('kh').json['status']

    update_placement(second.id, {'resolution' => 'completed'})
    assert_equal 'doing', Item.get('kh').json['status']
  end

  # retired is a declaration, not a drift state — recording the session is right,
  # reinterpreting the intent is not.
  def test_a_completed_session_never_un_retires_the_game
    set_status('kh', 'doing')
    set_status('kh', 'retired')
    placement = assign_to_date('kh', '2026-08-18', 'c1')

    update_placement(placement.id, {'resolution' => 'completed'})

    assert_equal 'retired', Item.get('kh').json['status']
    assert_equal '2026-08-18', Item.get(placement.item_id).json['started']
  end

  def test_flipping_to_doing_by_hand_opens_an_instance
    set_status('kh', 'doing')

    assert_equal 1, Item.get('kh').children.length
  end

  # Unlike staging or dating, `doing` is the claim that you have begun — so it stamps.
  # Without this the item reads `doing` while its only run reads "not started", and the
  # run then collapses to a single day when closed.
  def test_flipping_to_doing_by_hand_starts_the_run
    set_status('kh', 'doing')

    instance_id = Item.get('kh').children.first
    assert_equal Date.today.iso8601, Item.get(instance_id).json['started']
  end

  # Staging is "I want this this week" and dating is "I plan to" — neither has begun.
  def test_staging_and_dating_open_a_run_without_starting_it
    staged = create_floating_placement('kh', 'c1')
    assert_nil Item.get(staged.item_id).json['started']

    dated = assign_to_date('kh', '2026-09-01', 'c1')
    assert_nil Item.get(dated.item_id).json['started']
  end

  # Earliest wins, not first-writer-wins: the two doors can fire in either order, and a
  # start that depended on which ran first would be arbitrary.
  def test_a_session_played_earlier_moves_the_start_back
    set_status('kh', 'doing')
    placement = assign_to_date('kh', '2026-08-18', 'c1')

    update_placement(placement.id, {'resolution' => 'completed'})

    assert_equal '2026-08-18', Item.get(placement.item_id).json['started']
  end

  def test_a_later_session_leaves_the_start_alone
    set_status('kh', 'doing')
    started = Item.get(Item.get('kh').children.first).json['started']
    placement = assign_to_date('kh', '2099-01-01', 'c1')

    update_placement(placement.id, {'resolution' => 'completed'})

    assert_equal started, Item.get(placement.item_id).json['started']
  end

  def test_backfilling_a_past_instance
    instance = create_instance('kh', {'finished' => '2016-08-04'})

    assert_equal 'completed', instance.json['status']
    assert_equal '2016-08-04', instance.json['finished']
    assert_equal 'kh', instance.parent
  end

  def test_backfill_refuses_an_item_that_does_not_track_instances
    Item.new({'id' => 'tacos', 'name' => 'Tacos'}).save!

    assert_raises(ListError::BadRequest) { create_instance('tacos', {}) }
  end

  def test_a_recipe_is_completely_unaffected
    Item.new({'id' => 'tacos', 'name' => 'Tacos'}).save!
    placement = create_floating_placement('tacos', 'c1', '2026-08-17')

    assert_equal 'tacos', placement.item_id
    assert_equal 'tacos', placement.catalog_item_id
    assert_nil Item.get('tacos').children
  end

end
