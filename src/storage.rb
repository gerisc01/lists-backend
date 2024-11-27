require 'ruby-schema-storage'

module TypeStorage

  attr_accessor :instance
  @instance = nil

  def self.global_storage
    if @instance.nil? && is_e2e_test
      @instance = SchemaTypeStorage.new('e2e-data')
    elsif @instance.nil? && test_var_set
      @instance = SchemaTypeStorage.new('data-test')
    elsif @instance.nil?
      @instance = SchemaTypeStorage.new
    end
    @instance
  end

  def self.is_e2e_test
    !ENV['LISTS_BACKEND_E2E_TEST'].nil? && ENV['LISTS_BACKEND_E2E_TEST'].downcase.start_with?('t')
  end

  def self.test_var_set
    !ENV['TEST_STORAGE'].nil? && ENV['TEST_STORAGE'].downcase.start_with?('t')
  end

  def self.clear_e2e_data
    @instance.clear_cache unless @instance.nil?
    Dir.glob('e2e-data/*').each do |file|
      File.delete(file)
    end
    Dir.delete('e2e-data') if Dir.exist?('e2e-data')
  end

  def self.clear_test_storage
    @instance.clear_cache unless @instance.nil?
    Dir.glob('data-test/*').each do |file|
      File.delete(file)
    end
    Dir.delete('data-test') if Dir.exist?('data-test')
  end

end