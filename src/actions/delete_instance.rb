require_relative '../type/item'
require_relative './resolve_open_instance'
require_relative './set_status'

# Removes a run that shouldn't exist, unlinking it from the parent — a soft-deleted child left in
# `children` still gets counted. Its placements are left for reconcile to prune.
def delete_instance(instance_id, actor_id = nil)
  instance = Item.get(instance_id)
  raise ListError::NotFound, "item id '#{instance_id}' not found" if instance.nil?

  parent = instance.parent.nil? ? nil : Item.get(instance.parent)
  raise ListError::BadRequest, "item '#{instance_id}' is not an instance" if parent.nil?

  parent.json['children'] = (parent.children || []) - [instance.id]
  parent.validate
  parent.save!

  instance.delete!
  return revert_status_after_delete(parent, actor_id) || parent
end

# Undoes the doing flip the run caused, unless another run is still open.
def revert_status_after_delete(parent, actor_id = nil)
  return nil if parent.json['status'] != 'doing'
  return nil if !open_instance_for(parent).nil?

  last = (parent.json['transitions'] || []).last
  return nil if last.nil? || last['to'] != 'doing' || last['from'].to_s.empty?

  return set_status(parent.id, last['from'], actor_id)
end
