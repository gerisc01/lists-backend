require_relative '../../src/db/item_db'

class TestItemDb < ItemDb
  @@file_name = "integration_test_item.json"

  def self.get_cache
    return @@loaded_objs
  end

  def self.teardown
    self.cache_clear
    File.delete(@@file_name) if File.exist?(@@file_name)
  end
end