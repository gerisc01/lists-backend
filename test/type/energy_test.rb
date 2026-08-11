require_relative '../minitest_wrapper'
require_relative '../../src/type/item'
require_relative '../../src/type/energy'

class EnergyTest < MinitestWrapper

  def test_type_match_accepts_only_the_three_tiers
    assert Energy.type_match?('chill')
    assert Energy.type_match?('moderate')
    assert Energy.type_match?('intense')
    refute Energy.type_match?('exhausting')
    refute Energy.type_match?(nil)
    refute Energy.type_match?(2)
  end

  def test_of_defaults_absent_to_moderate
    assert_equal 'moderate', Energy.of(nil)
    assert_equal 'chill', Energy.of('chill')
    assert_equal 'intense', Energy.of('intense')
  end

  def test_of_item_reads_the_stored_field
    unrated = Item.new({'id' => 'e-unrated', 'name' => 'Unrated'})
    chill = Item.new({'id' => 'e-chill', 'name' => 'Chill', 'energy' => 'chill'})
    assert_equal 'moderate', Energy.of_item(unrated)
    assert_equal 'chill', Energy.of_item(chill)
  end

  # The load-bearing difference from Status: `want-to` is stamped at construction,
  # energy deliberately is not, so absent stays absent and means moderate.
  def test_the_default_is_never_persisted_on_create
    item = Item.new({'id' => 'e-default', 'name' => 'No rating'})
    item.validate
    item.save!
    assert_nil Item.get('e-default').json['energy']
    assert_equal 'want-to', Item.get('e-default').json['status']
  end

  def test_item_persists_energy_and_rejects_an_unknown_tier
    item = Item.new({'id' => 'e-persist', 'name' => 'Mop the floors', 'energy' => 'intense'})
    item.validate
    item.save!
    assert_equal 'intense', Item.get('e-persist').json['energy']

    bad = Item.new({'id' => 'e-bad', 'name' => 'Bad', 'energy' => 'somewhat'})
    assert_raises(StandardError) { bad.validate }
  end

end
