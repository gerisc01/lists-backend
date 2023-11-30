require_relative '../type/list'

def move_item(id, from_list, to_list)
  throw ListError::BadRequest, "Can't move item without a from_list and a to_list" if from_list.to_s.empty? || to_list.to_s.empty?
  
  item = ItemGeneric.get(id)
  from = List.get(from_list)
  from.remove_item(item)
  to = List.get(to_list)
  to.add_item(item)
  from.save!
  to.save!
end

def copy_item(id, to_list)
  throw ListError::BadRequest, "Can't move item without a to_list" if to_list.to_s.empty?
  
  item = ItemGeneric.get(id)
  to = List.get(to_list)
  to.add_item(item)
  to.save!
end

def remove_item(id, list_id)
  throw ListError::BadRequest, "Can't remove an item without a list_id" if list.to_s.empty?
  
  item = ItemGeneric.get(id)
  list = List.get(list_id)
  list.remove_item(item)
  list.save!
end