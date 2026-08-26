require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/actions/resolve_open_instance'

class ResolveOpenInstanceTest < MinitestWrapper

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

    @recipe = Item.new({'id' => 'tacos', 'name' => 'Tacos'})
    @recipe.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  # The property the whole feature ships behind: an item whose template does not opt in
  # is returned untouched, so every existing caller behaves exactly as before.
  def test_no_attribute_is_a_no_op
    assert_equal 'tacos', resolve_open_instance('tacos')
    assert_nil Item.get('tacos').children
  end

  def test_mints_an_instance_on_first_resolve
    instance_id = resolve_open_instance('kh')

    refute_equal 'kh', instance_id
    instance = Item.get(instance_id)
    assert_equal 'kh', instance.parent
    assert_equal ['playthrough'], instance.templates
    assert_equal 'Kingdom Hearts — Playthrough', instance.name
    assert_equal [instance_id], Item.get('kh').children
  end

  # Minting is "this exists", not "this has begun" — staging opens an instance before
  # any session has happened.
  def test_minted_instance_is_unstarted
    instance = Item.get(resolve_open_instance('kh'))

    assert_equal Status::DEFAULT, instance.json['status']
    assert_nil instance.json['started']
  end

  def test_resolve_is_idempotent
    first = resolve_open_instance('kh')
    second = resolve_open_instance('kh')

    assert_equal first, second
    assert_equal 1, Item.get('kh').children.length
  end

  def test_a_closed_instance_does_not_block_the_next_one
    first = resolve_open_instance('kh')
    set_instance_status(first, 'completed')

    second = resolve_open_instance('kh')

    refute_equal first, second
    assert_equal [first, second], Item.get('kh').children
  end

  # An instance is itself an item, and its own template has no `instances` attribute —
  # so resolving one returns it unchanged rather than nesting.
  def test_resolving_an_instance_does_not_nest
    instance_id = resolve_open_instance('kh')

    assert_equal instance_id, resolve_open_instance(instance_id)
  end

  def test_unknown_item_is_returned_unchanged
    assert_equal 'NOT_FOUND', resolve_open_instance('NOT_FOUND')
  end

  private

  def set_instance_status(id, status)
    instance = Item.get(id)
    instance.json['status'] = status
    instance.save!
  end

end
