require_relative '../type/item_generic'
require_relative '../type/list'

def copy_item(id, to_list)
  raise ListError::BadRequest, "Can't copy item without a to_list" if to_list.to_s.empty?

  item = ItemGeneric.get(id)
  raise ListError::NotFound, "Item (#{id}) Not Found" if item.nil?
  to = List.get(to_list)
  raise ListError::NotFound, "List (#{to_list}) Not Found" if to.nil?
  to.add_item(item)
  to.save!
  return item
end
