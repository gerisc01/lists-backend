require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../src/storage'

class MinitestWrapper < Minitest::Test
  ENV['TEST_STORAGE'] = 'true'
  ENV['RACK_ENV'] = 'test'

  def after_teardown()
    TypeStorage.clear_test_storage
    if defined?(Day)
      Day.clear_cache
      Day.toggle_cache_source(:prod)
    end
  end
end
