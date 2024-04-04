require_relative '../type/item'

def set_field(id, key, value)
  begin
    item = Item.get(id)
    raise "item id '#{id}' not found" if item.nil?
    item.public_send("#{key}=", value)
    item.save!
  rescue Exception => e
    raise ListError::BadRequest, "Failed to set field on item: #{e.message}"
  end
end