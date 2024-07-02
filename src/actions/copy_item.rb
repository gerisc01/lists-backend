require_relative '../type/item_generic'
require_relative '../type/list'

def copy_item(id, to_list)
  raise ListError::BadRequest, "Can't move item without a to_list" if to_list.to_s.empty?

  begin
    item = ItemGeneric.get(id)
    raise "item id '#{id}' not found" if item.nil?
    to = List.get(to_list)
    raise "to_list id '#{to_list}' not found" if to.nil?
    to.add_item(item)
    to.save!
  rescue Exception => e
    raise ListError::BadRequest, "Failed to copy item: #{e.message}"
  end

end
