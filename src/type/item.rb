require 'securerandom'
require 'json'
require 'date'
require_relative '../db/item_db'
require_relative '../exceptions.rb'

class Item

  @@fields = [
    {
      "key" => "starred",
      "type" => "boolean"
    },
    {
      "key" => "tags",
      "type" => "array",
      "subkey" => "tag",
      "subtype" => "string"
    },
    {
      "key" => "finished",
      "type" => "date"
    }
  ]

  @@fields.each do |field|
    define_method(field["key"].to_sym) { return @json[field["key"]] }
    define_method("#{field["key"]}=".to_sym) { |value| @json[field["key"]] = value }

    if field["type"].to_s.downcase == "boolean"
      define_method "is_#{field["key"]}".to_sym do
        return @json[field["key"]]
      end

      define_method "set_#{field["key"]}".to_sym do |value|
        raise ValidationError, "Invalid Field: value '#{value}' is not a boolean type" if !(value.is_a?(TrueClass) || value.is_a?(FalseClass))
        @json[field["key"]] = value
      end
    elsif field["type"].to_s.downcase == "date"
      define_method "set_#{field["key"]}".to_sym do |value|
        if value.is_a?(Date)
          date = value
        elsif value.is_a?(String)
          begin
            date = Date.parse(value)
          rescue
            raise ValidationError, "Invalid Field: value '#{value}' is not a valid date string (yyyy-mm-dd)"
          end
        else
          raise ValidationError, "Invalid Field: value '#{value}' is not a date or date string"
        end
        @json[field["key"]] = date
      end
    elsif field["type"].to_s.downcase == "array"
      define_method "add_#{field["subkey"]}".to_sym do |value|
        if field["subtype"].to_s.downcase == "string" && !value.is_a?(String)
          raise ValidationError, "Invalid Field: array value '#{value}' is not a string"
        end
        @json[field["key"]] = [] if @json[field["key"]].nil?
        @json[field["key"]] << value
      end

      define_method "remove_#{field["subkey"]}".to_sym do |value|
        return if @json[field["key"]].nil?
        @json[field["key"]].select! { |it| it != value }
      end
    end
  end

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