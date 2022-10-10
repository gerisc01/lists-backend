require 'securerandom'
require 'json'
require_relative './collection_db'
require_relative '../list/list'
require_relative '../helpers/exceptions.rb'

class Collection

  @@collection_db = CollectionDb
  @@keys = ["id", "key", "name", "lists"]
  @@keys.each do |key|
    define_method(key.to_sym) { return @json[key] }
    define_method("#{key}=".to_sym) { |value| @json[key] = value }
  end

  attr_reader :json

  def initialize(json = nil)
    @json = json.nil? ? {} : json
    @json["id"] = SecureRandom.uuid if @json["id"].nil?
    @json["lists"] = [] if @json["lists"].nil?
  end

  def validate
    raise ValidationError, "Invalid Collection: id cannot be empty" if self.id.to_s.empty?
    raise ValidationError, "Invalid Collection (#{self.id}): name cannot be empty" if self.name.to_s.empty?
    raise ValidationError, "Invalid Collection (#{self.id}): lists needs to be a list" if self.lists.nil? || !self.lists.is_a?(Array)
  end

  def add_list(list)
    raise ValidationError, "Invalid Collection State: lists is not type list" if self.lists.nil? || !self.lists.is_a?(Array)
    list.save! if !List.exist?(list.id)
    lists << list.id
  end

  def remove_list(list)
    return unless list.is_a?(List) || list.is_a?(String)
    raise ValidationError, "Invalid Collection State: lists is not type list" if self.lists.nil? || !self.lists.is_a?(Array)
    listId = list.is_a?(List) ? list.id : list
    lists.select! { |it| it != listId }
  end

  ## Generic Methods

  def self.from_object(json)
    Collection.new(json)
  end

  def to_object
    return @json
  end

  def merge!(json)
    @json = @json.merge(json)
  end

  def self.get(id)
    return @@collection_db.get(id)
  end

  def self.list
    return @@collection_db.list()
  end

  def save!
    validate()
    @@collection_db.save(self)
  end

  def delete!
    raise BadRequestError, "Invalid Collection: id cannot be nil" if self.id.to_s.empty?
    @@collection_db.delete(self.id)
  end

  def self.set_db_class(clazz)
    @@collection_db = clazz
  end

end