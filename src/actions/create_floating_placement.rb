require_relative '../type/placement'
require_relative './resolve_open_instance'
require_relative './resolve_group_member'
require_relative './revive_for_planning'
require_relative '../type/item_generic'

# Create a floating (dayless) Placement for (item, collection): a placement that
# lives in staging with no date yet. Sibling of assign_to_date; the floating
# counterpart of a dated placement. Binding it to a day later (bind_placement)
# just sets the date and clears the flag — one entity, two states. See
# docs/DECISIONS.md "Placement is a first-class type".
#
# `staged_week` (Monday week-start, YYYY-MM-DD) anchors this floating placement to a
# week — the planner is a weekly plan, so the pile reads only the current week
# (docs/DECISIONS.md). Optional so legacy/dateless callers still work.
#
# Deduped on (item, collection) for OPEN placements: re-staging an item that already
# has an open floating placement RE-STAMPS its staged_week to the passed week and
# returns it (re-staging means "I want this *this* week") rather than piling up
# duplicates. A resolved (e.g. lapsed) placement is not matched — re-staging a
# lapsed one-off is a fresh instance, not a resurrection.
def create_floating_placement(item_id, collection_id, staged_week = nil)
  # Two guards with the resolve between them, because a group and an item are separate
  # stores that must never mix (ItemGeneric.exist? is the "either kind" query). The
  # second guard is what enforces it: whatever we resolved to must be a real Item,
  # since a Placement can only ever point at one.
  raise ListError::NotFound, "item id '#{item_id}' not found" unless ItemGeneric.exist?(item_id)
  item_id = resolve_group_member(item_id)
  raise ListError::NotFound, "item id '#{item_id}' not found" unless Item.exist?(item_id)
  raise ListError::NotFound, "collection id '#{collection_id}' not found" unless Collection.exist?(collection_id)

  # Staging a repeat-tracked item stages its OPEN INSTANCE, minting one if there is
  # none — a placement records a session of one playthrough, not of the game in the
  # abstract. A no-op for every other item. The dedupe below then keys on the instance,
  # which is what makes re-staging return the same row.
  item_id = resolve_open_instance(item_id)

  # Planning a terminal item revives it — see revive_for_planning.rb. Placed AFTER the
  # instance seam so it lands on whatever the placement will actually point at: for a
  # run-keeping item that is a fresh instance at want-to, so this is a no-op and the
  # completed playthrough behind it stays completed.
  revive_for_planning(item_id)

  existing = Placement.floating_for_collection(collection_id)
                      .find { |p| p.item_id == item_id && p.resolution.nil? }
  unless existing.nil?
    if staged_week && existing.staged_week != staged_week
      existing.staged_week = staged_week
      existing.validate
      existing.save!
    end
    return existing
  end

  placement = Placement.new({
    'item_id' => item_id,
    'collection_id' => collection_id,
    'date' => nil,
    'floating' => true,
    'staged_week' => staged_week,
  })
  placement.validate
  placement.save!
  placement
end
