require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../helpers'
require_relative '../../src/type/template'

class TemplateTest < Minitest::Test

  def setup
    @template = Template.new
    @template.key = 'test'
    @template.display_name = 'Test'
    @template.fields = [
      {:key => 'anything-goes'},
      {:key => 'everything-sym', :required => false, :type => Array, :subtype => String, :type_ref => true, :display_name => 'Items'},
      {:key => 'everything-str', 'required' => false, 'type' => Array, 'subtype' => String, 'type_ref' => true, 'display_name' => 'Items'}
    ]
  end

  def teardown
  end

  def test_tempate_round_trip_jsonstr
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
end