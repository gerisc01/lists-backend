require_relative '../minitest_wrapper'
require_relative '../helpers'
require_relative '../../src/type/template'
require_relative '../../src/type/template_types/week_days'
require_relative '../../src/type/item'
require_relative '../../src/type/list'

class WeekDaysTest < MinitestWrapper

  def setup
    @template = Template.new
    @template.id = '1'
    @template.key = 'test'
    @template.display_name = 'Test'
    @template.fields = [
      {:key => 'days', :required => false, :type => SchemaType::WeekDays, :display_name => 'Days'},
    ]
    @template.save!
  end

  def teardown
    TypeStorage.clear_test_storage
  end

  def test_week_days_type_match
    item = Item.new({'id' => '1', 'name' => 'Test', 'days' => ['M'], 'templates' => ['1']})
    item.validate
  end

  def test_week_days_type_match_failure
    item = Item.new({'id' => '1', 'name' => 'Test', 'days' => 'M', 'templates' => ['1']})
    assert_raises(Schema::ValidationError) { item.validate }
  end

  def test_week_days_single
    item = Item.new({'id' => '1', 'name' => 'Test', 'days' => ['M'], 'templates' => ['1']})
    item.validate
  end

  def test_week_days_multiple_different_cases
    item = Item.new({'id' => '1', 'name' => 'Test', 'days' => ['M', 't'], 'templates' => ['1']})
    item.validate
  end

  def test_week_days_all
    item = Item.new({'id' => '1', 'name' => 'Test', 'days' => ['M', 'T', 'W', 'Th', 'F', 'Sa', 'Su'], 'templates' => ['1']})
    item.validate
  end

  def test_week_days_failure
    item = Item.new({'id' => '1', 'name' => 'Test', 'days' => ['M', 'a', 'T'], 'templates' => ['1']})
    assert_raises(Schema::ValidationError) { item.validate }
  end
end