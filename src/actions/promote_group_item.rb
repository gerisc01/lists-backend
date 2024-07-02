require_relative '../type/item_group'
require_relative '../type/list'

def promote_group_item(item_id, group_item_id, list_id)
  raise ListError::BadRequest, "Need an item_id, group_item_id, and list_id to promote an item " if item_id.to_s.empty? || group_item_id.to_s.empty? || list_id.to_s.empty?

  begin
    item = ItemGroup.get(item_id)
    raise "group id '#{item_id}' not found" if item.nil?
    list = List.get(list_id)
    raise "list_id '#{list_id}' not found" if list.nil?
    raise "list_id '#{list_id}' does not have a group with id '#{item_id}'" if !list.items || !list.items.include?(item_id)
    raise "group with id '#{item_id}' does not have an item id '#{group_item_id}'" unless item.group.include?(group_item_id)
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
  rescue Exception => e
    raise ListError::BadRequest, "Failed to move item: #{e.message}"
  end
end