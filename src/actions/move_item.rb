require_relative '../type/item_generic'
require_relative '../type/list'

def move_item(id, from_list, to_list)
  raise ListError::BadRequest, "Can't move item without a from_list and a to_list" if from_list.to_s.empty? || to_list.to_s.empty?

  begin
    item = ItemGeneric.get(id)
    raise "item id '#{id}' not found" if item.nil?
    from = List.get(from_list)
    raise "from_list id '#{from_list}' not found" if from.nil?
    raise "from_list '#{from_list}' does not have an item with id '#{id}'" unless from.items.include?(id)
    from.remove_item(item)
    to = List.get(to_list)
    raise "to_list id '#{to_list}' not found" if to.nil?
    to.add_item(item)
    from.save!
    to.save!
  rescue Exception => e
    raise ListError::BadRequest, "Failed to move item: #{e.message}"
  end
end