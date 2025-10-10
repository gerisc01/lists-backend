require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/item_group'
require_relative '../../src/type/list'
require_relative '../../src/actions/add_item_to_field'

class GroupedActionTest < MinitestWrapper

  def setup
    # name (string), platforms (array of strings), length (integer)
    @game_template = create_game_template
    @game_template.save!

    # name (string), platform (string), finished (date), platinumed (date)
    @playthrough_template = create_playthrough_template
    @playthrough_template.save!

    @parent = Item.new({'id' => '1', 'name' => 'Hades', 'platforms' => ['PC', 'PS5'], 'length' => 50, 'templates' => ['game-template']})
    @parent.save!
    @list1 = List.new({'id' => 'a', 'name' => 'Games', 'items' => [@parent.id]})
    @list1.save!
    @list2 = List.new({'id' => 'b', 'name' => 'Playthroughs'})
    @list2.save!
  end

  def teardown
    TypeStorage.clear_test_storage
    mocha_teardown
  end

  def test_replace_field_then_copy_item
    move_item = ActionStep.new({
     'type' => 'moveItem',
     'fixed_params' => {'from_list' => @list1.id, 'to_list' => @list2.id},
     'input_params' => ['item_id']
    })

    set_field = ActionStep.new({
      'type' => 'setField',
      'fixed_params' => {'key' => 'platform', 'value' => 'PS5'},
      'input_params' => ['item_id']
    })

    action = Action.new({
      'name' => 'Move to new list',
      'steps' => [
        move_item,
        set_field
      ],
      'inputs' => {
        'id' => 'Item',
      }
    })
    action.save!

    action.process({'item_id' => @parent.id})
    assert_equal [], @list1.items
    assert_equal ['1'], @list2.items
    assert_equal 'PS5', @parent.json['platform']
  end

  def test_duplicate_item_then_add_to_children
    duplicate_item = ActionStep.new({
     'type' => 'duplicateItem',
     'fixed_params' => {'to_list' => @list2.id},
     'input_params' => ['item_id']
    })

    add_to_field = ActionStep.new({
      'type' => 'addItemToField',
      'fixed_params' => {'key' => 'children'},
      'dynamic_params' => {'value' => "duplicateItem.id"},
      'input_params' => ['item_id', 'value']
    })

    action = Action.new({
      'name' => 'Start Playthrough',
      'steps' => [
        duplicate_item,
        add_to_field
      ],
      'inputs' => {
        'item_id' => 'Item'
      }
    })
    action.save!

    assert_nil @parent.children
    action.process({'item_id' => @parent.id})
    # Find the new duplicated item
    dup = Item.list.select { |i| i.id != @parent.id }.first
    assert dup.id != @parent.id
    assert !dup.id.to_s.empty?
    assert_equal [dup.id], @parent.children
    assert_equal [dup.id], @list2.items

  end

  private

  def create_game_template
    temp = Template.new
    temp.id = 'game-template'
    temp.key = 'game-template'
    temp.display_name = 'Game Template'
    temp.fields = [
      {:key => 'name', :type => String},
      {:key => 'platforms', :type => Array, :subtype => String},
      {:key => 'length', :type => Integer}
    ]
    return temp
  end

  def create_playthrough_template
    temp = Template.new
    temp.id = 'playthrough-template'
    temp.key = 'playthrough-template'
    temp.display_name = 'Playthrough Template'
    temp.fields = [
      {:key => 'name', :type => String},
      {:key => 'platform', :type => String},
      {:key => 'finished', :type => SchemaType::Date},
      {:key => 'platinumed', :type => SchemaType::Date}
    ]
    return temp
  end

end
