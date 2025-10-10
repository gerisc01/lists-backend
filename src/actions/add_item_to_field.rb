require_relative '../type/item'

def add_item_to_field(id, key, value)
  begin
    item = Item.get(id)
    raise "item id '#{id}' not found" if item.nil?
    if item.json[key].nil?
      item.json[key] = [value] if item.json[key].nil?
    else
      raise "field '#{key}' does not accept multiple values" unless item.json[key].respond_to?(:push)
      item.json[key].push(value)
    end
    item.validate
    item.save!
  rescue Exception => e
    raise ListError::BadRequest, "Failed to set field on item: #{e.message}"
  end
end
