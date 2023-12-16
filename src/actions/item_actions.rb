require_relative '../type/list'

def move_item(id, from_list, to_list)
  raise ListError::BadRequest, "Can't move item without a from_list and a to_list" if from_list.to_s.empty? || to_list.to_s.empty?

  begin
    item = ItemGeneric.get(id)
    from = List.get(from_list)
    from.remove_item(item)
    to = List.get(to_list)
    to.add_item(item)
    from.save!
    to.save!
  rescue Exception => e
    raise ListError::BadRequest, "Failed to move item: #{e.message}"
  end
end

def copy_item(id, to_list)
  raise ListError::BadRequest, "Can't move item without a to_list" if to_list.to_s.empty?

  begin
    item = ItemGeneric.get(id)
    to = List.get(to_list)
    to.add_item(item)
    to.save!
  rescue Exception => e
    raise ListError::BadRequest, "Failed to copy item: #{e.message}"
  end

end

def remove_item(id, list_id, item_index = nil)
  raise ListError::BadRequest, "Can't remove an item without a list_id" if list_id.to_s.empty?

  begin
    list = List.get(list_id)
    if item_index
      list_items = list.items
      if id != list.items[item_index]
        raise ListError::BadRequest, "Can't remove the item at index '#{item_index}' because it doesn't match the id '#{id}'"
      end
      list_items.delete_at(item_index)
      list.items = list_items
    else
      list.remove_item(id)
    end
    list.save!
  rescue Exception => e
    raise ListError::BadRequest, "Failed to remove item: #{e.message}"
  end
end