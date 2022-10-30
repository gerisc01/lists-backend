require 'securerandom'
require 'json'
require_relative './collection_db'
require_relative '../list/list'
require_relative '../template/template'
require_relative '../helpers/exceptions'
require_relative '../schema/schema'

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
    "lists" => {:required => false, :type => Array, :display_name => 'Lists'},
    "templates" => {:required => false, :type => Hash, :display_name => 'Templates'}
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

  def add_template(template)
    template.validate
    self.templates = {} if self.templates.nil?
    raise BadRequestError, "Bad Request: expecting template to be a Template instance" if !template.is_a?(Template)
    raise ValidationError, "Invalid Collection State: templates is not type hash" if !self.templates.is_a?(Hash)
    key = template.key
    raise BadRequestError, "Bad Request: Cannot add template to collection because key already exists" if self.templates.has_key?(key)
    templates[key] = template
  end

  def remove_template(key)
    return if self.templates.nil?
    self.templates.delete(key)
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