require_relative '../type/item'
require_relative './resolve_open_instance'

# The manual door into an instance — the only one that is a user action rather than a
# side effect of planning. Two jobs, one shape:
#
#   backfill    "I finished this in 2016"  — history the app was not running for and
#               cannot infer. Bulk import is this same door with a different front end.
#   correction  "I actually started this a month ago" — the reason `started` and
#               `finished` are ordinary template fields rather than derived from the
#               transitions journal, which set_status owns and which must stay
#               uneditable.
#
# Status is derived from the dates rather than passed: an instance with a `finished`
# date is a closed one, anything else is open. That keeps the client from being able to
# create a record that says it finished and is still running.
def create_instance(item_id, fields = {})
  item = Item.get(item_id)
  raise ListError::NotFound, "item id '#{item_id}' not found" if item.nil?

  template_id = instance_template_for(item)
  if template_id.nil?
    raise ListError::BadRequest, "item '#{item_id}' does not track instances"
  end

  fields = (fields || {}).reject { |key, _| RESERVED_INSTANCE_FIELDS.include?(key) }
  fields['status'] = 'completed' unless fields['finished'].to_s.empty?

  mint_instance(item, template_id, fields)
end

# Identity is the server's to assign — a client supplying its own parent or templates
# could hang an instance off the wrong item or give it a template with no dates.
RESERVED_INSTANCE_FIELDS = %w[id parent templates children transitions].freeze
