# Field keys the CODE reads by name, as opposed to the ones it merely renders.
#
# The test that puts a key here: does some code look it up by name? `finished` is here
# because the instance ledger counts and orders by it. `platform`, `platinumed`,
# `difficulty` are not, because nothing reads them — they render generically, whatever
# they are called. Everything a template author invents is in the second group.
#
# These contracts already existed informally before this file: HIDDEN_FIELDS in the
# frontend's Fields.js is the de facto register, except it is a rendering filter, so
# nothing tells a template author those keys are taken. Two entries there (`todo-date`,
# `completed`) are retired concepts that can never be removed, because old items still
# carry values. This file exists so the list is managed rather than discovered.
#
# Enforcement is server-side deliberately: a disabled input in the editor does not
# survive curl, a second client, or a script.
module ReservedFields

  # Keys the instance ledger depends on. `started` is deliberately NOT here — it is
  # optional and the ledger already degrades without it (Instances.js renders "not
  # started"), so pinning it would restrict more than the feature actually needs.
  INSTANCE_CONTRACT = %w[finished].freeze

  # The wider set the app reads by name, mirroring the frontend's HIDDEN_FIELDS. Not yet
  # enforced against collisions — a template field named "Status" still keys to `status`
  # and is silently swallowed at render. Recorded here so the fix has one home.
  SYSTEM_KEYS = %w[
    name id templates tags parent children
    status transitions completed energy scheduling
    recurring-event recurring-parent recurring-children todo-date
    updated_at lastAccessed
  ].freeze

  # The default definition for a contract field, used when opting a template in without
  # one. Display name is a suggestion — rename it to "Watched" for films and the ledger
  # is unaffected, because only the KEY is the contract.
  def self.contract_field(key)
    {
      'key' => key,
      'display_name' => key.capitalize,
      'type' => 'SchemaType::Date',
      'required' => false,
    }
  end

end
