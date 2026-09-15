require 'time'

# The catalog item's lifecycle status. A small validation type (responds to
# `type_match?`) so the schema enforces the enum server-side, the same mechanism
# SchemaType::Boolean / SchemaType::Date use. See docs/DECISIONS.md:
# "completed/retired are first-class statuses, not reasons on done".
class Status

  VALUES  = %w[want-to doing on-hold completed retired].freeze
  DEFAULT = 'want-to'

  # `done` is a derived predicate, not a stored value: the planner's "is it done?"
  # query and archive-eligibility read this rather than a `done` status.
  TERMINAL = %w[completed retired].freeze

  def self.type_match?(value)
    VALUES.include?(value)
  end

  def self.done?(value)
    TERMINAL.include?(value)
  end

end

# One entry in an item's append-only status history. Also a validation type:
# `type_match?` enforces the entry shape, so a malformed transition can't be
# persisted. `set_status` is the sole writer, so this is belt-and-suspenders that
# also documents the shape in one place. Entry is `{from, to, at, by?}` — fully
# self-describing from from→to, so no `reason` field is needed.
#
# `by` is the account whose request made the change. Absent, never null, when no person
# acted: reconcile's auto-archive, the unauthenticated e2e path, and every entry written
# before authors were recorded. It is the ACTOR, not the placement's `resolved_by` — the
# journal answers "who changed this", and who did the work already lives on the
# placement (0084).
class Transition

  def self.type_match?(value)
    value.is_a?(Hash) &&
      Status::VALUES.include?(value['to']) &&
      (value['from'].nil? || Status::VALUES.include?(value['from'])) &&
      value['at'].is_a?(String) &&
      (value['by'].nil? || value['by'].is_a?(String))
  end

  # Build a stamped entry. The timestamp is server-owned and cannot be supplied
  # by a client, and neither can the author — it comes from the request, not the body.
  def self.build(from:, to:, by: nil)
    entry = { 'from' => from, 'to' => to, 'at' => Time.now.utc.iso8601 }
    entry['by'] = by unless by.nil?
    entry
  end

end
