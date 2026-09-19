require 'date'
require_relative '../type/item'
require_relative '../type/placement'
require_relative './auto_archive'

# Safe to re-run. Deletes placements whose item is gone; for weeks before as_of_date's, unstages shelf
# items and lapses one-offs; then archives one-offs whose placements are all resolved.
def reconcile(as_of_date: Date.today.iso8601)
  released = []
  lapsed = []
  current_week_start = monday_of(as_of_date)

  pruned = Placement.list.select { |p| Item.get(p.item_id).nil? }
  pruned.each(&:delete!)

  Placement.list.each do |placement|
    next if !placement.resolution.nil?
    item = Item.get(placement.item_id)
    next if item.nil?

    floating_past = !placement.staged_week.nil? && placement.staged_week < current_week_start
    dated_past_week = !placement.date.nil? && placement.date < current_week_start

    if item_has_shelf_home?(item.id)
      # A dated past placement of a shelf item is kept.
      if floating_past
        placement.delete!
        released << placement
      end
    elsif floating_past || dated_past_week
      placement.resolution = 'lapsed'
      placement.resolved_at = Time.now.utc.iso8601
      placement.validate
      placement.save!
      lapsed << placement
    end
  end

  archived = Placement.list.map(&:item_id).uniq.map do |item_id|
    maybe_auto_archive(item_id, as_of_date: as_of_date)
  end.compact

  return {
    'released' => released.map(&:id),
    'lapsed' => lapsed.map(&:id),
    'archived' => archived.map(&:id),
    'pruned' => pruned.map(&:id),
  }
end

# The frontend's weeks start Monday too (getStartOfWeek(date, 1)), and it stamps staged_week.
def monday_of(iso_date)
  d = Date.parse(iso_date)
  return (d - ((d.wday - 1) % 7)).iso8601
end
