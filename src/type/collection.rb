require 'securerandom'
require 'json'
require_relative '../db/collection_db'
require_relative '../schema/schema'
require_relative './list'
require_relative './template'
require_relative '../exceptions'

class Collection

  @@collection_db = CollectionDb
  attr_accessor :json

  @@schema = Schema.new
  @@schema.key = "collection"
  @@schema.display_name = "Collection"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "key" => {:required => false, :type => String, :display_name => 'Key'},
    "name" => {:required => true, :type => String, :display_name => 'Name'},
    "lists" => {:required => false, :type => Array, :subtype => List, :type_ref => true, :display_name => 'Lists'},
    "templates" => {:required => false, :type => Hash, :subtype => Template, :display_name => 'Templates'}
  }
  @@schema.apply_schema(self)

  def initialize(json = nil)
    @json = json.nil? ? {} : json
    @json["id"] = SecureRandom.uuid if @json["id"].nil?
    @json["lists"] = [] if @json["lists"].nil?
  end

  def validate
    @@schema.validate(self)
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

  def self.get_by_key(key)
    return list().select { |col| col.key == key }
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