# The catalog item's "how much does this demand of me?" axis (design.md §2.1's
# universal spine, alongside lifecycle status). A small validation type (responds
# to `type_match?`) so the schema enforces the enum server-side — the same
# mechanism Status / Resolution / Scheduling use.
#
# One genuinely cross-domain axis: it absorbs *mood* for movies/games (a chill
# comedy, a mindless game) and *effort/dread* for tasks (the project you'll put
# off => intense). Deliberately NOT active effort, which is the narrow cooking
# fact of hands-on vs. walk-away time and stays a template field.
#
# ABSENT (nil) = `moderate`. Unlike Status, the default is *never persisted*:
# `Item#initialize` does not stamp it, so an item nobody has rated stores no
# energy at all. Absent and 'moderate' are the same answer ("assume baseline
# unless told otherwise"), which is what lets a "low energy tonight" query treat
# every unrated item as baseline rather than as unknown. Read it through `of`
# rather than reaching for the raw field.
#
# Current and mutable, and a property of the *item* — read, never re-set, per
# placement. Written through the ordinary item update path: unlike `status`
# there is no history requirement, so it needs no server-authoritative setter.
# See docs/DECISIONS.md "Energy's capture home is on-add + item details".
class Energy

  VALUES  = %w[chill moderate intense].freeze
  DEFAULT = 'moderate'

  def self.type_match?(value)
    VALUES.include?(value)
  end

  # The effective energy for a raw stored value (nil/absent => DEFAULT).
  def self.of(value)
    value || DEFAULT
  end

  # The effective energy of an item, for callers holding the item rather than
  # the field (the shape `Scheduling.type_of` / `Scheduling.event?` established).
  def self.of_item(item)
    of(item.json['energy'])
  end

end
