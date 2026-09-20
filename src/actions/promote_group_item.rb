require_relative '../type/item_group'
require_relative '../type/list'

def promote_group_item(item_id, group_item_id, list_id)
  raise ListError::BadRequest, "Need an item_id, group_item_id, and list_id to promote an item" if item_id.to_s.empty? || group_item_id.to_s.empty? || list_id.to_s.empty?

  item = ItemGroup.get(item_id)
  raise ListError::NotFound, "Item group (#{item_id}) Not Found" if item.nil?
  list = List.get(list_id)
  raise ListError::NotFound, "List (#{list_id}) Not Found" if list.nil?
  raise ListError::BadRequest, "List (#{list_id}) does not have a group with id '#{item_id}'" if list.items.nil? || !list.items.include?(item_id)
  raise ListError::BadRequest, "Item group (#{item_id}) does not have an item with id '#{group_item_id}'" if !item.group.include?(group_item_id)
  updated_items = list.items
  if item.group.length == 1
    updated_items.delete(item_id)
  elsif item.group.length == 2
    non_group_item_id = item.group.select { |id| id != group_item_id }.first
    updated_items[updated_items.index(item_id)] = non_group_item_id
  else
    updated_group = item.group
    updated_group.delete(group_item_id)
    item.group = updated_group
    item.save!
  end
  updated_items << group_item_id
  list.items = updated_items
  list.save!
  return list
end
