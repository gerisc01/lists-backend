require_relative '../type/item'
require_relative './resolve_open_instance'

# Records a past or corrected run. Status comes from the dates: a `finished` date makes it completed.
def create_instance(item_id, fields = {})
  item = Item.get(item_id)
  raise ListError::NotFound, "item id '#{item_id}' not found" if item.nil?

  template_id = instance_template_for(item)
  if template_id.nil?
    raise ListError::BadRequest, "item '#{item_id}' does not track instances"
  end

  fields = (fields || {}).reject { |key, _| RESERVED_INSTANCE_FIELDS.include?(key) }
  fields['status'] = 'completed' if !fields['finished'].to_s.empty?

  return mint_instance(item, template_id, fields)
end

RESERVED_INSTANCE_FIELDS = %w[id parent templates children transitions].freeze
