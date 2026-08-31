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
  # occurrence/leftover killer, also a §4.4 staging exit); `lapsed` = a weekly-plan
  # item that was staged for a week and never acted on, released by reconcile when
  # that week passed (its own outcome, distinct from a deliberate `skipped`, so a
  # future per-week report can tell "sat there, did nothing" apart from "chose not
  # to"). See docs/DECISIONS.md "Weekly planning is a weekly PLAN, not a backlog".
  # A fourth, derived case — an *event* whose day is past — is NOT a stored value:
  # `Placement#resolved?` is the predicate; nothing resolves by the passage of time.
  VALUES = %w[completed skipped lapsed].freeze

  def self.type_match?(value)
    VALUES.include?(value)
  end

end
