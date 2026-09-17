require_relative './tag'
require_relative './template'
require_relative '../exceptions'

class ItemGeneric

  def self.from_schema_object(json)
    if !json.nil? && json.has_key?('group')
      return ItemGroup.new(json)
    else
      return Item.new(json)
    end
  end

  def self.exist?(id)
    return Item.exist?(id) || ItemGroup.exist?(id)
  end

  def self.get(id)
    return Item.get(id) || ItemGroup.get(id)
  end

  def self.type_match?(type)
    return type.is_a?(Item) || type.is_a?(ItemGroup)
  end

end