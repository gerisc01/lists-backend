require_relative '../type/item'

def set_field(id, key, value)
  item = Item.get(id)
  raise ListError::NotFound, "Item (#{id}) Not Found" if item.nil?
  item.json[key] = value
  item.save!
  return item
end
