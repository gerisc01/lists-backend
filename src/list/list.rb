require 'securerandom'
require 'json'
require_relative './list_db'
require_relative '../item/item'
require_relative '../helpers/exceptions.rb'
require_relative '../schema/schema'

class List

  @@list_db = ListDb
  attr_accessor :json

  @@schema = Schema.new
  @@schema.key = "list"
  @@schema.display_name = "List"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "name" => {:required => true, :type => String, :display_name => 'Name'},
    "items" => {:required => false, :type => Array, :subtype => Item, :type_ref => true, :display_name => 'Items'},
    "template" => {:required => false, :type => String, :display_name => 'Template'}
  }
  @@schema.apply_schema(self)

  def initialize(json = nil)
    @json = json.nil? ? {} : json
    @json["id"] = SecureRandom.uuid if @json["id"].nil?
    @json["items"] = [] if @json["items"].nil?
  end

  def validate
    @@schema.validate(self)
  end

  def set_template(key)
    raise BadRequestError, "Template key needs to be a string" if key.nil? || !key.is_a?(String)
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