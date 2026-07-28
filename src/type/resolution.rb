# How a placement instance was closed. A small validation type (responds to
# `type_match?`) so the schema enforces the enum server-side — the same mechanism
# Status uses on the item. Mirrors the item-status shape the owner chose: explicit
# first-class values + a *derived* `resolved?` predicate (on Placement), never a
# pile of semi-exclusive booleans. See docs/DECISIONS.md "placement resolution =
# completed|skipped".
#
# ABSENT (nil) = open — the instance hasn't been closed. There is deliberately no
# DEFAULT: an unresolved placement stores no resolution at all, so "resolved?"
# reads presence, not a sentinel.
class Resolution

  # `completed` = it happened; `skipped` = it genuinely didn't need to (the §2.5
  # occurrence/leftover killer, also a §4.4 staging exit). A third derived case —
  # an *event* whose day is past — is NOT a stored value: it's computed by
  # Placement#resolved? from the item's scheduling kind, so events need no write.
  VALUES = %w[completed skipped].freeze

  def self.type_match?(value)
    VALUES.include?(value)
  end

end
