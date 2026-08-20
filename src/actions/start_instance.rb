require 'date'
require_relative '../type/item'
require_relative '../type/status'
require_relative './resolve_open_instance'
require_relative './set_status'

# OPENED IS NOT STARTED. Staging means "I want this this week", not "I began it", so
# resolve_open_instance mints an instance with no dates and leaves it at want-to. This
# is the other half: the FIRST COMPLETED SESSION is what actually starts an instance,
# stamps its `started` date, and moves the catalog item to `doing`.
#
# That split is what keeps a staged-but-never-played instance reading as unstarted
# rather than as "currently playing", and it is TODO.md § Someday's "start is implicit"
# applied to instances.
#
# The status move is deliberately NARROWER than the stamp: the instance always records
# what happened, but the catalog item's status only follows where doing so does not
# overwrite something you said explicitly.
#
#   want-to    -> doing    the ordinary first play
#   on-hold    -> doing    resuming; a paused item must resume before it can complete
#   completed  -> doing    the replay case, begun with no declared intent
#   retired    -> retired  a DECLARATION, not a drift state — never auto-reversed
#
# `retired` is excluded because it exists as a first-class status precisely because
# "I'm never finishing this" differs from "I finished it" (decision 0011). Recording
# the session is right; reinterpreting the intent is not.
def start_instance_for(placement)
  instance = Item.get(placement.item_id)
  return if instance.nil?

  parent = instance.parent.nil? ? nil : Item.get(instance.parent)
  return if parent.nil?
  return if instance_template_for(parent).nil?

  if instance.json['started'].to_s.empty?
    instance.json['started'] = placement.date || Date.today.iso8601
    instance.validate
    instance.save!
  end

  advance_to_doing(instance.id, instance.json['status'])
  advance_to_doing(parent.id, parent.json['status'])
end

# Move into `doing` unless already there or explicitly retired. Routed through
# set_status so the transition is journalled and timestamped like every other status
# change, rather than written as a bare field.
def advance_to_doing(item_id, current_status)
  return if current_status == 'doing' || current_status == 'retired'
  set_status(item_id, 'doing')
end
