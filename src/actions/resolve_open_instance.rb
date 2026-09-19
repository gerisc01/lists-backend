require 'date'
require_relative '../type/item'
# ItemGeneric (the type of parent/children) names ItemGroup without requiring it.
require_relative '../type/item_group'
require_relative '../type/template'
require_relative '../type/status'

# An instance is one run of an item (a replay, a rewatch): a child Item whose `parent` is the item.
# Returns the open instance's id, minting one if needed, or `item_id` when the template doesn't opt in.
def resolve_open_instance(item_id)
  item = Item.get(item_id)
  return item_id if item.nil?

  template_id = instance_template_for(item)
  return item_id if template_id.nil?

  open = open_instance_for(item)
  return open.id if !open.nil?

  return mint_instance(item, template_id).id
end

# The opt-in is `attributes.instances.template` on one of the item's templates.
def instance_template_for(item)
  (item.templates || []).each do |template_id|
    template = Template.get(template_id)
    next if template.nil?

    config = (template.attributes || {})['instances']
    next if !config.is_a?(Hash)

    child_template = config['template']
    return child_template if !child_template.to_s.empty?
  end
  return nil
end

# Open means not in a terminal status. At most one is open at a time.
def open_instance_for(item)
  (item.children || []).each do |child_id|
    child = Item.get(child_id)
    next if child.nil?
    next if Status.done?(child.json['status'])
    return child
  end
  return nil
end

# Born want-to with no dates; `fields` lets create_instance record a past run.
def mint_instance(item, template_id, fields = {})
  template = Template.get(template_id)
  raise ListError::NotFound, "instance template '#{template_id}' not found" if template.nil?

  # No number in the name: the ledger numbers runs by date, which stays right after a backfill.
  instance = Item.new({
    'name' => "#{item.name} — #{template.display_name}",
    'parent' => item.id,
    'templates' => [template_id],
  }.merge(fields))
  instance.validate
  instance.save!

  item.json['children'] = (item.children || []) + [instance.id]
  item.validate
  item.save!

  return instance
end

# The earliest date wins, whichever caller runs first: a session's own date, or today for a flip to doing.
def stamp_instance_start(instance, date)
  return instance if instance.nil? || date.to_s.empty?

  current = instance.json['started'].to_s
  return instance if !current.empty? && date >= current

  instance.json['started'] = date
  instance.validate
  instance.save!
  return instance
end
