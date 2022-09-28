require 'securerandom'
require 'json'
require_relative './item_db'
require_relative '../helpers/exceptions.rb'

class Item

  @@item_db = ItemDb
  @@keys = ["id", "name"]
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
    raise ValidationError, "Invalid Item: id cannot be empty" if self.id.to_s.empty?
    raise ValidationError, "Invalid Item (#{self.id}): name cannot be empty" if self.name.to_s.empty?
  end

  ## Generic Methods

  def self.from_object(json)
    Item.new(json)
  end

  def to_object
    return @json
  end

  def merge!(json)
    @json = @json.merge(json)
  end

  def self.get(id)
    return @@item_db.get(id)
  end

  def self.exist?(id)
    return @@item_db.get(id) != nil
  end

  def self.list
    return @@item_db.list()
  end

  def save!
    validate()
    @@item_db.save(self)
  end

  def delete!
    raise BadRequestError, "Invalid Item: id cannot be nil" if self.id.to_s.empty?
    @@item_db.delete(self.id)
  end

  def self.set_db_class(clazz)
    @@item_db = clazz
  end

end