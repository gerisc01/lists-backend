require_relative '../minitest_wrapper'
require_relative '../helpers'
require_relative '../../src/type/account'

class AccountTest < MinitestWrapper

  def setup
    @account = Account.new({'name' => 'Test Account'})
  end

  def test_account_attributes_round_trip
    attributes = { 'view' => { 'depth' => 'rollup' }, 'default-headers' => ['games', 'movies'] }
    @account.attributes = attributes
    assert_equal attributes, @account.attributes

    empty_attributes = {}
    @account.attributes = empty_attributes
    assert_equal empty_attributes, @account.attributes

    @account.attributes = nil
    assert_nil @account.attributes
  end

  def test_account_attributes_persist
    attributes = { 'view' => { 'depth' => 'rollup' } }
    @account.attributes = attributes
    @account.save!

    reloaded = Account.get(@account.id)
    assert_equal attributes, reloaded.attributes
  end

end
