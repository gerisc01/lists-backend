require_relative '../../type/item'
require_relative '../../type/item_group'
require_relative '../../type/item_generic'

module ApiHelpers

  def self.convert_item_ids_to_items(item_ids)
    items = []
    if !item_ids.nil?
      item_ids.each do |item_id|
        it = ItemGeneric.get(item_id)
        if it.is_a?(Item)
          items.push(it.to_schema_object)
        elsif it.is_a?(ItemGroup)
          items.push(it.to_schema_object)
          it.group.each do |group_id|
            group_it = Item.get(group_id)
            items.push(group_it.to_schema_object)
          end
        end
      end
    end
    return items
  end
end