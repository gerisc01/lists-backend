require_relative '../type/item'

def add_item_to_field(id, key, value)
  item = Item.get(id)
  raise ListError::NotFound, "Item (#{id}) Not Found" if item.nil?
  if item.json[key].nil?
    item.json[key] = [value]
  else
    raise ListError::BadRequest, "Field '#{key}' does not accept multiple values" if !item.json[key].respond_to?(:push)
    item.json[key].push(value)
  end
  item.validate
  item.save!
  return item
end
