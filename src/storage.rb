require 'ruby-schema-storage'

module TypeStorage

  attr_accessor :instance

  def self.global_storage
    if @instance.nil?
      @instance = SchemaTypeStorage.new
    end
    @instance
  end

end