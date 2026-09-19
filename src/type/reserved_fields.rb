# Field keys that code reads by name. A key belongs here only if something looks it up.
module ReservedFields

  # The frontend's Instances.js counts and orders by these. It copes without `started`.
  INSTANCE_CONTRACT = %w[finished].freeze

  # Matches the frontend's HIDDEN_FIELDS (Fields.js): a template field with one of these keys would
  # never render, so Template#validate refuses it.
  SYSTEM_KEYS = %w[
    name id templates tags parent children
    status transitions completed energy scheduling owner
    recurring-event recurring-parent recurring-children todo-date
    updated_at lastAccessed
  ].freeze

  # Declared by the `todo` and `recurring-item` templates themselves.
  TEMPLATE_DECLARABLE = %w[name completed todo-date recurring-event recurring-parent recurring-children].freeze

  # Only the key is the contract; the display name can be renamed.
  def self.contract_field(key)
    return {
      'key' => key,
      'display_name' => key.capitalize,
      'type' => 'SchemaType::Date',
      'required' => false,
    }
  end

end
