
require_relative '../../type/item'
require_relative '../../type/item_group'
require_relative '../../type/item_generic'

module ApiHelpers

  def self.convert_item_ids_to_items(item_ids)
    # Start with a hash to avoid duplicates, then convert to an array before returning
    items = {}

    items_to_retrieve = item_ids.dup
    while !items_to_retrieve.nil? && items_to_retrieve.length > 0
      item_id = items_to_retrieve.shift
      next if item_id.nil? || items.has_key?(item_id)

      it = ItemGeneric.get(item_id)
      unless it.nil?
        items[it.id] = it.to_schema_object
        related_ids = get_related_ids(it)
        items_to_retrieve += related_ids
      end
    end
    return items.values
  end

  def self.get_related_ids(item)
    related_ids = []
    if item.respond_to?(:children) && !item.children.nil?
      item.children.each do |child_id|
        related_ids.push(child_id)
      end
    end
    if item.respond_to?(:group) && !item.group.nil?
      item.group.each do |group_id|
        related_ids.push(group_id)
      end
    end
    related_ids
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
