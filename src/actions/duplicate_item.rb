require_relative '../type/item_generic'
require_relative '../type/list'

def duplicate_item(id, to_list)
  item = ItemGeneric.get(id)
  raise ListError::NotFound, "Item (#{id}) Not Found" if item.nil?
  json = item.to_schema_object.dup
  json.delete('id')
  if item.is_a?(ItemGroup)
    duplicated_item = ItemGroup.new(json)
  elsif item.is_a?(Item)
    duplicated_item = Item.new(json)
  else
    raise ListError::BadRequest, "Item (#{id}) is not an Item or ItemGroup"
  end
  if !to_list.to_s.empty?
    to = List.get(to_list)
    raise ListError::NotFound, "List (#{to_list}) Not Found" if to.nil?
    to.add_item(duplicated_item)

    duplicated_item.save!
    to.save!
  else
    duplicated_item.save!
  end

  return duplicated_item
end
