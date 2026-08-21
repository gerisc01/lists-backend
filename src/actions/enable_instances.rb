require_relative '../type/template'
require_relative '../type/reserved_fields'

# Opt a template into keeping a record: every item using it grows an INSTANCE for each
# complete engagement (see resolve_open_instance.rb). This is the action behind the
# editor's "Keep a record of each time" control, and the only supported way to write
# `attributes.instances`.
#
# It GUARANTEES the contract rather than trusting the caller — if the child template has
# no `finished` field, one is added. The editor also disables that field's remove button,
# but the editor is not where a guarantee can live: curl, a second client, or a script all
# bypass it. Here, nothing does.
#
# Passing a nil child DISABLES it: minting stops and every instance already recorded stays
# exactly where it is. Deleting history because a setting was flipped is never the right
# default — the record is the point of the feature.
def enable_instances(parent_template_id, child_template_id = nil)
  parent = Template.get(parent_template_id)
  raise ListError::NotFound, "template id '#{parent_template_id}' not found" if parent.nil?

  if child_template_id.to_s.empty?
    attributes = parent.attributes || {}
    attributes.delete('instances')
    parent.attributes = attributes
    parent.validate
    parent.save!
    return parent
  end

  child = Template.get(child_template_id)
  raise ListError::NotFound, "template id '#{child_template_id}' not found" if child.nil?
  if child.id == parent.id
    raise ListError::BadRequest, "a template cannot keep a record of itself"
  end

  ensure_contract_fields(child)

  parent.attributes = (parent.attributes || {}).merge('instances' => { 'template' => child.id })
  parent.validate
  parent.save!
  parent
end

# Add any contract field the child is missing, leaving existing ones untouched — including
# their display names, so a "Watched" label survives being re-pointed at.
def ensure_contract_fields(template)
  existing = (template.fields || []).map { |field| field.key }
  missing = ReservedFields::INSTANCE_CONTRACT - existing
  return template if missing.empty?

  fields = (template.fields || []).map { |field| field.to_schema_object }
  missing.each { |key| fields << ReservedFields.contract_field(key) }
  template.fields = fields
  template.validate
  template.save!
  template
end
