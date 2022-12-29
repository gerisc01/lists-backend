require 'securerandom'
require 'json'
require_relative './list'
require_relative '../exceptions'
require_relative '../schema/schema'

class Template

  attr_accessor :json

  @@schema = Schema.new
  @@schema.key = "collection"
  @@schema.display_name = "Collection"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "key" => {:required => true, :type => String, :display_name => 'Key'},
    "fields" => {:required => true, :type => Hash, :display_name => 'Templates'}
  }
  @@schema.apply_schema(self)

  def initialize(json = nil)
    @json = json.nil? ? {} : json
    @json["id"] = SecureRandom.uuid if @json["id"].nil?
  end

  def validate
    @@schema.validate(self)
  end

  ## Generic Methods

  def self.from_object(json)
    Template.new(json)
  end

  def to_object
    return @json
  end

  def merge!(json)
    @json = @json.merge(json)
  end

end