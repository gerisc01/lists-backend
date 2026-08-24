require_relative '../minitest_wrapper'
require_relative '../../src/type/template'
require_relative '../../src/actions/enable_instances'
require_relative '../../src/actions/resolve_open_instance'

class EnableInstancesTest < MinitestWrapper

  def setup
    @parent = template('game', 'Game', [field('name', 'Name', String, true)])
    @child = template('playthrough', 'Playthrough', [field('name', 'Name', String, true)])
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_adds_the_contract_field_when_missing
    enable_instances('game', 'playthrough')

    keys = Template.get('playthrough').fields.map(&:key)
    assert_includes keys, 'finished'
  end

  # A label is a suggestion, only the key is the contract — so re-pointing at a template
  # whose author renamed Finished to "Watched" must not clobber it.
  def test_leaves_an_existing_contract_field_alone
    template('watch', 'Watch', [
      field('name', 'Name', String, true),
      field('finished', 'Watched', SchemaType::Date, false),
    ])

    enable_instances('game', 'watch')

    finished = Template.get('watch').fields.find { |f| f.key == 'finished' }
    assert_equal 'Watched', finished.display_name
    assert_equal 1, Template.get('watch').fields.count { |f| f.key == 'finished' }
  end

  def test_wires_the_parent_and_is_readable_by_the_resolver
    enable_instances('game', 'playthrough')

    game = Item.new({'id' => 'kh', 'name' => 'Kingdom Hearts', 'templates' => ['game']})
    game.save!
    assert_equal 'playthrough', instance_template_for(game)
  end

  def test_is_idempotent
    enable_instances('game', 'playthrough')
    enable_instances('game', 'playthrough')

    assert_equal 1, Template.get('playthrough').fields.count { |f| f.key == 'finished' }
    assert_equal({ 'template' => 'playthrough' }, Template.get('game').attributes['instances'])
  end

  # Disabling stops minting. It must NOT touch instances already recorded — deleting
  # history because a setting flipped is never the right default.
  def test_disabling_clears_the_wiring
    enable_instances('game', 'playthrough')
    enable_instances('game', nil)

    assert_nil Template.get('game').attributes['instances']
    assert_includes Template.get('playthrough').fields.map(&:key), 'finished'
  end

  def test_refuses_to_keep_a_record_of_itself
    assert_raises(ListError::BadRequest) { enable_instances('game', 'game') }
  end

  # A record of a record is not inert: set_status calls resolve_open_instance on the
  # instance's own id when a session starts it, and instance_template_for works on any
  # item — so a third layer would actually mint. Capped at two regardless of which end
  # of the chain gets wired first.
  def test_refuses_to_make_a_record_template_into_a_parent
    template('session', 'Session', [field('name', 'Name', String, true)])
    enable_instances('game', 'playthrough')

    assert_raises(ListError::BadRequest) { enable_instances('playthrough', 'session') }
  end

  def test_refuses_to_point_at_a_child_that_already_has_its_own_record
    template('session', 'Session', [field('name', 'Name', String, true)])
    enable_instances('playthrough', 'session')

    assert_raises(ListError::BadRequest) { enable_instances('game', 'playthrough') }
  end

  # The guarantee the editor's disabled input only suggests.
  def test_cannot_drop_the_contract_field_while_referenced
    enable_instances('game', 'playthrough')

    child = Template.get('playthrough')
    child.fields = child.fields.reject { |f| f.key == 'finished' }.map(&:to_schema_object)

    assert_raises(ListError::Validation) { child.validate }
  end

  def test_can_drop_it_once_nothing_points_at_the_template
    enable_instances('game', 'playthrough')
    enable_instances('game', nil)

    child = Template.get('playthrough')
    child.fields = child.fields.reject { |f| f.key == 'finished' }.map(&:to_schema_object)

    child.validate # does not raise
    assert_equal ['name'], Template.get('playthrough').fields.map(&:key) if child.save!
  end

  private

  def field(key, display_name, type, required)
    { :key => key, :display_name => display_name, :type => type, :required => required }
  end

  def template(id, display_name, fields)
    t = Template.new
    t.id = id
    t.key = id
    t.display_name = display_name
    t.fields = fields
    t.save!
    t
  end

end
