require 'ruby-schema-storage'

module TypeStorage

  attr_accessor :instance
  @instance = nil

  def self.global_storage
    if @instance.nil? && test_var_set
      @instance = SchemaTypeStorage.new('data-test')
    elsif @instance.nil?
      @instance = SchemaTypeStorage.new
    end
    @instance
  end

  def self.test_var_set
    !ENV['TEST_STORAGE'].nil? && ENV['TEST_STORAGE'].downcase.start_with?('t')
  end

  def self.clear_test_storage
    @instance.clear_cache unless @instance.nil?
    Dir.glob('data-test/*').each do |file|
      File.delete(file)
    end
    Dir.delete('data-test') if Dir.exist?('data-test')
  end

end