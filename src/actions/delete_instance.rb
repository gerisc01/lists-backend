require_relative '../type/item'
require_relative './resolve_open_instance'
require_relative './set_status'

# Undo a run that should never have existed — a stray mint from flipping to `doing` by
# mistake, or a backfill typed against the wrong game.
#
# NOT the counterpart of close_instance. Closing says "this happened and is over" and is
# the point of the whole feature; this says "this never happened", which is why it is a
# separate door and why nothing calls it as a side effect.
#
# Unlinking from the parent is the part that cannot be skipped. `delete!` is a soft delete
# — it flags the record and drops it from `list()` — so a child removed without unlinking
# leaves a dangling id in `parent.children` that reads fine (the ledger tolerates a failed
# load) while quietly miscounting anything that walks children, which the corpus walk
# behind the ledger query does.
#
# Placements pointing at the run are deliberately left alone: the floating reads already
# exclude orphans whose item is deleted, and reconcile prunes the dead rows for good.
def delete_instance(instance_id)
  instance = Item.get(instance_id)
  raise ListError::NotFound, "item id '#{instance_id}' not found" if instance.nil?

  parent = instance.parent.nil? ? nil : Item.get(instance.parent)
  raise ListError::BadRequest, "item '#{instance_id}' is not an instance" if parent.nil?

  parent.json['children'] = (parent.children || []) - [instance.id]
  parent.validate
  parent.save!

  instance.delete!
  revert_status_after_delete(parent) || parent
end

# A run that never happened should not leave the status move it caused behind. This is not
# inferring intent the way auto-un-retiring would be — the delete is itself the declaration
# that it never happened, so undoing its side effect is symmetric to it.
#
# Routed through set_status, so the correction is journalled like every other transition
# instead of written as a bare field: the log honestly reads want-to → doing → want-to.
#
# Three guards, and the third is the one that isn't obvious — deleting an OLD run while a
# different one is still open must not touch a status that other run is holding.
def revert_status_after_delete(parent)
  return nil unless parent.json['status'] == 'doing'
  return nil unless open_instance_for(parent).nil?

  last = (parent.json['transitions'] || []).last
  return nil if last.nil? || last['to'] != 'doing' || last['from'].to_s.empty?

  set_status(parent.id, last['from'])
end
