# ruby
require_relative '../minitest_wrapper'
require_relative '../helpers'
require_relative '../../src/type/template'
require_relative '../../src/type/template_types/recurring_date'
require_relative '../../src/type/item'

class RecurringDateTest < MinitestWrapper

  def setup
    @template = Template.new
    @template.id = 'recurring-test'
    @template.key = 'recurring-test'
    @template.display_name = 'Recurring Test'
    @template.fields = [
      { :key => 'recurring', :required => false, :type => SchemaType::RecurringDate, :display_name => 'Recurring' },
    ]
    @template.save!
  end

  def teardown
    TypeStorage.clear_test_storage
  end

  def test_field_def_validation_subtype_rejected
    template = Template.new
    template.id = 'invalid-recurring'
    template.key = 'invalid-recurring'
    template.display_name = 'Invalid Recurring'
    assert_raises(Schema::ValidationError) {
      template.fields = [
        { :key => 'recurring', :required => false, :type => Array, :display_name => 'Recurring', :subtype => SchemaType::RecurringDate },
      ]
    }
  end

  def test_valid_minimal_recurring
    item = Item.new({ 'id' => '1', 'name' => 'Test', 'recurring' => { 'interval' => 1, 'type' => 'daily' }, 'templates' => ['recurring-test'] })
    item.validate
  end

  def test_missing_interval_fails
    item = Item.new({ 'id' => '1', 'name' => 'Test', 'recurring' => { 'type' => 'daily' }, 'templates' => ['recurring-test'] })
    assert_raises(Schema::ValidationError) { item.validate }
  end

  def test_interval_must_be_integer
    item = Item.new({ 'id' => '1', 'name' => 'Test', 'recurring' => { 'interval' => '1', 'type' => 'daily' }, 'templates' => ['recurring-test'] })
    assert_raises(Schema::ValidationError) { item.validate }
  end

  def test_missing_type_fails
    item = Item.new({ 'id' => '1', 'name' => 'Test', 'recurring' => { 'interval' => 1 }, 'templates' => ['recurring-test'] })
    assert_raises(Schema::ValidationError) { item.validate }
  end

  def test_invalid_type_value_fails
    item = Item.new({ 'id' => '1', 'name' => 'Test', 'recurring' => { 'interval' => 1, 'type' => 'century' }, 'templates' => ['recurring-test'] })
    assert_raises(Schema::ValidationError) { item.validate }
  end

  def test_end_date_parsing_failure
    item = Item.new({ 'id' => '1', 'name' => 'Test', 'recurring' => { 'interval' => 1, 'type' => 'monthly', 'end-date' => '2023-02-30' }, 'templates' => ['recurring-test'] })
    assert_raises(Schema::ValidationError) { item.validate }

    item = Item.new({ 'id' => '1', 'name' => 'Test', 'recurring' => { 'interval' => 1, 'type' => 'monthly', 'end-date' => 20230230 }, 'templates' => ['recurring-test'] })
    assert_raises(Schema::ValidationError) { item.validate }
  end

  def test_valid_end_date_accepts
    item = Item.new({ 'id' => '1', 'name' => 'Test', 'recurring' => { 'interval' => 1, 'type' => 'yearly', 'end-date' => '2025-12-31' }, 'templates' => ['recurring-test'] })
    item.validate
  end

  def test_type_is_case_insensitive
    item = Item.new({ 'id' => '1', 'name' => 'Test', 'recurring' => { 'interval' => 2, 'type' => 'Weekly' }, 'templates' => ['recurring-test'] })
    item.validate
  end

  def test_type_match_behavior
    assert SchemaType::RecurringDate.type_match?({ 'interval' => 1, 'type' => 'daily' })
    refute SchemaType::RecurringDate.type_match?('not-a-hash')
    refute SchemaType::RecurringDate.type_match?(['array'])
  end
end
