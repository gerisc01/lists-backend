require_relative '../minitest_wrapper'
require_relative '../helpers'
require_relative '../../src/type/template'
require_relative '../../src/type/item'

class TemplateTest < MinitestWrapper

  def setup
    @template = Template.new
    @template.id = '1'
    @template.key = 'test'
    @template.display_name = 'Test'
    @template.fields = [
      {:key => 'anything-goes'},
      {:key => 'everything-sym', :required => false, :type => Array, :subtype => String, :type_ref => true, :display_name => 'Items'},
      {:key => 'everything-str', 'required' => false, 'type' => Array, 'subtype' => String, 'type_ref' => true, 'display_name' => 'Items'},
      {:key => 'date', :required => false, :type => Template, :display_name => 'Date', :template_id => '2'},
      {:key => 'dates', :required => false, :type => Array, :subtype => Template, :display_name => 'Date', :template_id => '2'}
    ]
    @template.save!

    @date_template = Template.new
    @date_template.id = '2'
    @date_template.key = 'date_template'
    @date_template.display_name = 'Date Template'
    @date_template.fields = [
      {:key => 'year', :required => true, :type => Integer},
      {:key => 'month', :required => true, :type => Integer},
      {:key => 'day', :required => true, :type => Integer}
    ]
    @date_template.save!
  end

  def teardown
  end

  def test_template_round_trip_jsonstr
    jsonstr = @template.to_schema_object.to_json
    output = Template.from_schema_object(JSON.parse(jsonstr))
    assert_equal @template.key, output.key
    assert_equal @template.display_name, output.display_name

    anything_goes = output.fields.find { |f| f.key == 'anything-goes' }
    assert_equal 'anything-goes', anything_goes.key
    assert_nil anything_goes.display_name
    assert_nil anything_goes.type
    assert_nil anything_goes.subtype
    assert_nil anything_goes.required
    assert_nil anything_goes.type_ref

    everything_sym = output.fields.find { |f| f.key == 'everything-sym' }
    assert_equal 'everything-sym', everything_sym.key
    assert_equal 'Items', everything_sym.display_name
    assert_equal Array, everything_sym.type
    assert_equal String, everything_sym.subtype
    assert_equal false, everything_sym.required
    assert_equal true, everything_sym.type_ref

    everything_str = output.fields.find { |f| f.key == 'everything-str' }
    assert_equal 'everything-str', everything_str.key
    assert_equal 'Items', everything_str.display_name
    assert_equal Array, everything_str.type
    assert_equal String, everything_str.subtype
    assert_equal false, everything_str.required
    assert_equal true, everything_str.type_ref
  end

  def test_template_in_template_empty
    item = Item.new({'id' => '1', 'name' => 'One', 'templates' => ['1']})
    item.validate
  end

  def test_template_in_template
    item = Item.new({'id' => '1', 'name' => 'One', 'templates' => ['1']})
    item.json['date'] = {'year' => 2024, 'month' => 7, 'day' => 1}
    item.validate
  end

  def test_template_in_template_failure
    item = Item.new({'id' => '2', 'name' => 'One', 'templates' => ['1']})
    item.json['date'] = {'year' => 2024}
    assert_raises(Schema::ValidationError) { item.validate }

    item = Item.new({'id' => '2', 'name' => 'One', 'templates' => ['1']})
    item.json['date'] = [{'year' => 2024, 'month' => 7, 'day' => 1}]
    assert_raises(Schema::ValidationError) { item.validate }
  end

  def test_template_in_template_array
    item = Item.new({'id' => '3', 'name' => 'One', 'templates' => ['1']})
    item.json['dates'] = [
      {'year' => 2024, 'month' => 7, 'day' => 1},
      {'year' => 2024, 'month' => 7, 'day' => 2}
    ]
    item.validate
  end

  def test_template_in_template_array_failure
    item = Item.new({'id' => '4', 'name' => 'One', 'templates' => ['1']})
    item.json['dates'] = [
      {'year' => 2024, 'month' => 7, 'day' => 1},
      {'year' => 2024}
    ]
    assert_raises(Schema::ValidationError) { item.validate }
  end
end