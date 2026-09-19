require_relative '../type/template'
require_relative '../type/reserved_fields'

# The only writer of `attributes.instances`. Adds any missing contract field to the child template;
# a nil child turns it off and keeps existing instances.
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

  # Two levels at most: an instance's own template would otherwise mint instances of it.
  if Template.instance_child_ids.include?(parent.id)
    raise ListError::BadRequest, "'#{parent.display_name}' already keeps a record for another template and cannot itself be one"
  end
  if (child.attributes || {})['instances'].is_a?(Hash)
    raise ListError::BadRequest, "'#{child.display_name}' already keeps its own record and cannot also be one"
  end

  ensure_contract_fields(child)

  parent.attributes = (parent.attributes || {}).merge('instances' => { 'template' => child.id })
  parent.validate
  parent.save!
  return parent
end

# Leaves existing fields, and their display names, as they are.
def ensure_contract_fields(template)
  existing = (template.fields || []).map { |field| field.key }
  missing = ReservedFields::INSTANCE_CONTRACT - existing
  return template if missing.empty?

  fields = (template.fields || []).map { |field| field.to_schema_object }
  missing.each { |key| fields << ReservedFields.contract_field(key) }
  template.fields = fields
  template.validate
  template.save!
  return template
end
