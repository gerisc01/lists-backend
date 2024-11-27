require_relative '../../type/item'
require_relative '../../type/item_group'
require_relative '../../type/item_generic'

module ApiHelpers

  def self.convert_item_ids_to_items(item_ids)
    items = []
    if !item_ids.nil?
      item_ids.reject { |it| it.nil? }.each do |item_id|
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

  def self.convert_since_format(instances, since)
    updated_info = {
      'deleted_ids' => [],
      'objects' => []
    }
    since_instances = instances.select { |it| it['updated_at'] > since }
    updated_info['deleted_ids'] = since_instances.select { |it| it['deleted'] }.map { |it| it['id'] }
    updated_info['objects'] = since_instances.reject { |it| it['deleted'] }
    return updated_info
  end
end