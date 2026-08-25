require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/template'
require_relative '../../src/actions/delete_instance'
require_relative '../../src/actions/enable_instances'
require_relative '../../src/actions/resolve_open_instance'
require_relative '../../src/actions/set_status'

class DeleteInstanceTest < MinitestWrapper

  def setup
    Template.new({'id' => 'playthrough', 'key' => 'playthrough', 'display_name' => 'Playthrough',
                  'fields' => [{'key' => 'name', 'display_name' => 'Name', 'type' => String, 'required' => true}]}).save!
    Template.new({'id' => 'game', 'key' => 'game', 'display_name' => 'Game',
                  'fields' => [{'key' => 'name', 'display_name' => 'Name', 'type' => String, 'required' => true}]}).save!
    enable_instances('game', 'playthrough')
    Item.new({'id' => 'kh', 'name' => 'Kingdom Hearts', 'templates' => ['game']}).save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def open_run
    set_status('kh', 'doing')
    Item.get('kh').children.first
  end

  # The part that cannot be skipped: a dangling id reads fine but miscounts anything
  # that walks children.
  def test_unlinks_the_run_from_its_parent
    id = open_run
    assert_equal [id], Item.get('kh').children

    delete_instance(id)

    assert_empty Item.get('kh').children
  end

  def test_soft_deletes_the_run
    id = open_run

    delete_instance(id)

    refute_includes Item.list.map(&:id), id
  end

  # Deleting the open run leaves nothing open, so the next stage mints a fresh one
  # rather than resurrecting the mistake.
  def test_the_next_stage_mints_a_new_run
    first = open_run
    delete_instance(first)

    second = resolve_open_instance('kh')

    refute_equal first, second
    assert_equal [second], Item.get('kh').children
  end

  # The mis-tap this exists for: one mistake should cost one undo, not two.
  def test_reverts_the_status_the_run_caused
    id = open_run
    assert_equal 'doing', Item.get('kh').json['status']

    delete_instance(id)

    assert_equal 'want-to', Item.get('kh').json['status']
  end

  # Deleting a replay's run must land back on completed — the earlier playthrough still
  # happened, so want-to would lose it.
  def test_reverting_a_replay_lands_back_on_completed
    set_status('kh', 'completed')
    id = open_run

    delete_instance(id)

    assert_equal 'completed', Item.get('kh').json['status']
  end

  # Staging never moved the status, so there is nothing of this run's to undo.
  def test_leaves_a_status_the_run_never_moved
    instance_id = resolve_open_instance('kh')
    assert_equal 'want-to', Item.get('kh').json['status']

    delete_instance(instance_id)

    assert_equal 'want-to', Item.get('kh').json['status']
  end

  # `doing` is being held by the run still open, not by the one going away.
  def test_leaves_the_status_alone_while_another_run_is_open
    first = open_run
    finished = Item.get(first)
    finished.json['status'] = 'completed'
    finished.save!
    resolve_open_instance('kh')

    delete_instance(first)

    assert_equal 'doing', Item.get('kh').json['status']
  end

  # on-hold was a later, separate declaration — not this run's side effect.
  def test_leaves_a_status_moved_on_since
    id = open_run
    set_status('kh', 'on-hold')

    delete_instance(id)

    assert_equal 'on-hold', Item.get('kh').json['status']
  end

  def test_refuses_an_item_that_is_not_an_instance
    assert_raises(ListError::BadRequest) { delete_instance('kh') }
  end

  def test_refuses_an_id_that_does_not_exist
    assert_raises(ListError::NotFound) { delete_instance('nope') }
  end

  # Only the named run goes — the rest of the ledger is untouched.
  def test_leaves_sibling_runs_alone
    first = open_run
    # Terminal, so it stops being "the open one" and a second run can mint alongside it.
    finished = Item.get(first)
    finished.json['status'] = 'completed'
    finished.save!
    second = resolve_open_instance('kh')

    delete_instance(second)

    assert_equal [first], Item.get('kh').children
    assert_includes Item.list.map(&:id), first
  end

end
