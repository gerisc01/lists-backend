require_relative '../type/list'

def remove_item(id, list_id, item_index = nil)
  raise ListError::BadRequest, "Can't remove an item without a list_id" if list_id.to_s.empty?

  begin
    list = List.get(list_id)
    raise "list_id id '#{list_id}' not found" if list.nil?
    if !item_index.nil? && !item_index.to_s.empty?
      list_items = list.items
      if id != list.items[item_index]
        raise ListError::BadRequest, "Can't remove the item at index '#{item_index}' because it doesn't match the id '#{id}'"
      end
      list_items.delete_at(item_index)
      list.items = list_items
    else
      raise "list_id '#{list_id}' does not have an item with id '#{id}'" if list.items.nil? || !list.items.include?(id)
      list.remove_item(id)
    end
    list.save!
  rescue Exception => e
    raise ListError::BadRequest, "Failed to remove item: #{e.message}"
  end
end