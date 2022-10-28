require 'securerandom'
require 'json'
require_relative './list_db'
require_relative '../item/item'
require_relative '../helpers/exceptions.rb'

class List

  @@list_db = ListDb
  @@keys = ["id", "name", "items", "template"]
  @@keys.each do |key|
    define_method(key.to_sym) { return @json[key] }
    define_method("#{key}=".to_sym) { |value| @json[key] = value }
  end

  attr_reader :json

  def initialize(json = nil)
    @json = json.nil? ? {} : json
    @json["id"] = SecureRandom.uuid if @json["id"].nil?
    @json["items"] = [] if @json["items"].nil?
  end

  def validate
    raise ValidationError, "Invalid List: id cannot be empty" if self.id.to_s.empty?
    raise ValidationError, "Invalid List (#{self.id}): name cannot be empty" if self.name.to_s.empty?
    raise ValidationError, "Invalid List (#{self.id}): items needs to be a list" if self.items.nil? || !self.items.is_a?(Array)
    raise ValidationError, "Invalid List (#{self.id}): template needs to be a string" if !self.template.nil? && !self.template.is_a?(String)
  end

  def add_item(item)
    raise ValidationError, "Invalid List State: items is not type list" if self.items.nil? || !self.items.is_a?(Array)
    item.save! if !Item.exist?(item.id)
    items << item.id
  end

  def remove_item(item)
    return unless item.is_a?(Item) || item.is_a?(String)
    raise ValidationError, "Invalid List State: items is not type list" if self.items.nil? || !self.items.is_a?(Array)
    itemId = item.is_a?(Item) ? item.id : item
    items.select! { |it| it != itemId }
  end

  def set_template(key)
    raise BadRequest, "Template key needs to be a string" if !key.nil? || key.is_a?(String)
    self.template = key
  end

  def remove_template
    self.template = nil
  end

  ## Generic Methods

  def self.from_object(json)
    List.new(json)
  end

  def to_object
    return @json
  end

  def merge!(json)
    @json = @json.merge(json)
  end

  def self.get(id)
    return @@list_db.get(id)
  end

  def self.list
    return @@list_db.list()
  end

  def save!
    validate()
    @@list_db.save(self)
  end

  def delete!
    raise BadRequestError, "Invalid List: id cannot be nil" if self.id.to_s.empty?
    @@list_db.delete(self.id)
  end

  def self.set_db_class(clazz)
    @@list_db = clazz
  end

end