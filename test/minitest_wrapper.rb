require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../src/storage'

class MinitestWrapper < Minitest::Test
  ENV['TEST_STORAGE'] = 'true'

  i_suck_and_my_tests_are_order_dependent!()

  def after_teardown()
    TypeStorage.clear_test_storage
  end
end