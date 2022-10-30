require 'securerandom'
require 'json'
require_relative '../list/list'
require_relative '../helpers/exceptions.rb'
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
  # @@keys = ["id", "key", "fields"]
  # @@keys.each do |key|
  #   define_method(key.to_sym) { return @json[key] }
  #   define_method("#{key}=".to_sym) { |value| @json[key] = value }
  # end

  # attr_reader :json

  def initialize(json = nil)
    @json = json.nil? ? {} : json
    @json["id"] = SecureRandom.uuid if @json["id"].nil?
  end

  def validate
    @@schema.validate(self)
    # raise ValidationError, "Invalid Template: id cannot be empty" if self.id.to_s.empty?
    # raise ValidationError, "Invalid Template (#{self.id}): key cannot be empty" if self.key.to_s.empty?
    # raise ValidationError, "Invalid Template (#{self.id}): fields cannot be empty and must be a hash" if self.fields.nil? || !self.fields.is_a?(Hash)
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