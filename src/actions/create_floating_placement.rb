require_relative '../type/placement'

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
  raise ListError::NotFound, "item id '#{item_id}' not found" unless Item.exist?(item_id)
  raise ListError::NotFound, "collection id '#{collection_id}' not found" unless Collection.exist?(collection_id)

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
