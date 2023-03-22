require 'securerandom'
require 'json'
require_relative '../schema/schema'
require_relative '../type/tag'
require_relative '../type/template'
require_relative '../exceptions'
require_relative '../base/base_type'
require_relative '../generator/type_generator'
require_relative '../generator/db_generator'

class ItemGeneric

  def self.from_object(json)
    if !json.nil? && json.has_key?('group')
      return ItemGroup.new(json)
    else
      return Item.new(json)
    end
  end

  def self.exist?(id)
    Item.exist?(id) || ItemGroup.exist?(id)
  end

  def self.get(id)
    Item.get(id) || ItemGroup.get(id)
  end

  def self.type_match?(type)
    return type.is_a?(Item) || type.is_a?(ItemGroup)
  end

end