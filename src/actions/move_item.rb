require_relative '../type/item_generic'
require_relative '../type/list'

def move_item(id, from_list, to_list)
  raise ListError::BadRequest, "Can't move item without a from_list and a to_list" if from_list.to_s.empty? || to_list.to_s.empty?

  item = ItemGeneric.get(id)
  raise ListError::NotFound, "Item (#{id}) Not Found" if item.nil?
  from = List.get(from_list)
  raise ListError::NotFound, "List (#{from_list}) Not Found" if from.nil?
  raise ListError::BadRequest, "List (#{from_list}) does not have an item with id '#{id}'" if from.items.nil? || !from.items.include?(id)
  to = List.get(to_list)
  raise ListError::NotFound, "List (#{to_list}) Not Found" if to.nil?
  from.remove_item(item)
  to.add_item(item)
  from.save!
  to.save!
  return item
end
