require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../src/storage'

class MinitestWrapper < Minitest::Test
  ENV['TEST_STORAGE'] = 'true'

  def after_teardown()
    TypeStorage.clear_test_storage
  end
end