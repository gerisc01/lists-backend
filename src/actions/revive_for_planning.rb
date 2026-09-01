require_relative '../type/item'
require_relative '../type/status'
require_relative './set_status'

# Planning a finished thing means you are not finished with it.
#
# This is the whole escape hatch for "I checked the garage off on Tuesday and then found
# out it was a bigger job". Rather than a second verb beside the day-view checkbox — a
# control standing on every row to serve the rare tap — the correction is made NEXT WEEK,
# when you actually know you want more, using the gesture you were making anyway: you
# stage it, or you drop it on a day.
#
# `want-to`, not `doing`: staging is intent ("I want this this week"), and only the status
# edge into `doing` claims you have begun. That distinction is load-bearing elsewhere —
# `doing` is what stamps an instance's start date (set_status.rb).
#
# A no-op for everything not terminal, which is the overwhelming majority of calls.
# Deliberately NOT applied to reopening a placement (update_placement with resolution nil):
# un-ticking a box is a mis-tap escape, and it already leaves the item wherever it was.
def revive_for_planning(item_id)
  item = Item.get(item_id)
  return if item.nil?
  return unless Status.done?(item.json['status'])

  set_status(item_id, 'want-to')
end
