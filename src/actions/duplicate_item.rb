require_relative '../type/item_generic'
require_relative '../type/list'

def duplicate_item(id, to_list)
  begin
    # Duplicate the item or item group
    item = ItemGeneric.get(id)
    raise "item id '#{id}' not found" if item.nil?
    json = item.to_schema_object.dup
    json.delete('id')
    if item.is_a?(ItemGroup)
      duplicated_item = ItemGroup.new(json)
    elsif item.is_a?(Item)
      duplicated_item = Item.new(json)
    else
      raise "item id '#{id}' is not an Item or ItemGroup"
    end
    # Add the item to a list if specified and then save both
    if !to_list.to_s.empty?
      to = List.get(to_list)
      raise "to_list id '#{to_list}' not found" if to.nil?
      to.add_item(duplicated_item)

      duplicated_item.save!
      to.save!
    else
      duplicated_item.save!
    end

    return duplicated_item
  rescue Exception => e
    raise ListError::BadRequest, "Failed to duplicate item: #{e.message}"
  end

end
