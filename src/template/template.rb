require 'securerandom'
require 'json'
require_relative '../list/list'
require_relative '../helpers/exceptions.rb'

class Template

  @@keys = ["id", "key", "fields"]
  @@keys.each do |key|
    define_method(key.to_sym) { return @json[key] }
    define_method("#{key}=".to_sym) { |value| @json[key] = value }
  end

  attr_reader :json

  def initialize(json = nil)
    @json = json.nil? ? {} : json
    @json["id"] = SecureRandom.uuid if @json["id"].nil?
  end

  def validate
    raise ValidationError, "Invalid Template: id cannot be empty" if self.id.to_s.empty?
    raise ValidationError, "Invalid Template (#{self.id}): key cannot be empty" if self.key.to_s.empty?
    raise ValidationError, "Invalid Template (#{self.id}): fields cannot be empty and must be a hash" if self.fields.nil? || !self.fields.is_a?(Hash)
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