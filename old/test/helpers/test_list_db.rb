require_relative '../../src/db/list_db'

class TestListDb < ListDb
  @@file_name = "integration_test_list.json"

  def self.get_cache
    return @@loaded_objs
  end

  def self.teardown
    self.cache_clear
    File.delete(@@file_name) if File.exist?(@@file_name)
  end
end