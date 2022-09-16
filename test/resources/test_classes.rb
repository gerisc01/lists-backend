require_relative '../../src/base_service'

class BaseServiceTest < BaseService
  @file_name = "base-test-file.json"
  @loaded_objs = nil

  attr_accessor :name

  def initialize(id, name)
    super()
    @id = id
    @name = name
  end

  def self.file_name
    @file_name
  end

  def self.get_loaded
    @loaded_objs
  end

  def self.clean_cache
    @loaded_objs = nil
  end

  def self.teardown
    clean_cache
    File.delete(@file_name) if File.exist?(@file_name)
  end

end

class GenericTestObj < BaseService
  @file_name = "generic-test-file.json"
  @loaded_objs = nil

  attr_accessor :name

  def initialize(id, name)
    super()
    @id = id
    @name = name
  end

  def self.get_loaded
    @loaded_objs
  end

  def self.clean_cache
    @loaded_objs = nil
  end

  def self.teardown
    clean_cache
    File.delete(@file_name) if File.exist?(@file_name)
  end

end