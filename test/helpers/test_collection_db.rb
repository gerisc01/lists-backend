require_relative '../../src/list/list_db'

class TestCollectionDb < CollectionDb
  @@file_name = "integration_test_collection.json"

  def self.get_cache
    return @@loaded_objs
  end

  def self.teardown
    self.cache_clear
    File.delete(@@file_name) if File.exist?(@@file_name)
  end
end