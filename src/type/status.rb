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
# also documents the shape in one place. Entry is `{from, to, at}` — fully
# self-describing from from→to, so no `reason` field is needed.
class Transition

  def self.type_match?(value)
    value.is_a?(Hash) &&
      Status::VALUES.include?(value['to']) &&
      (value['from'].nil? || Status::VALUES.include?(value['from'])) &&
      value['at'].is_a?(String)
  end

  # Build a stamped entry. The timestamp is server-owned and cannot be supplied
  # by a client.
  def self.build(from:, to:)
    { 'from' => from, 'to' => to, 'at' => Time.now.utc.iso8601 }
  end

end
