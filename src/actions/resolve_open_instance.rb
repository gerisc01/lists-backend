require 'date'
require_relative '../type/item'
# Writing item.parent / item.children validates against ItemGeneric, whose type_match?
# names ItemGroup without requiring it (item_generic.rb keeps that out to avoid a load
# cycle). Nothing had ever written those two fields before, so this is the first caller
# that has to pull ItemGroup in itself.
require_relative '../type/item_group'
require_relative '../type/template'
require_relative '../type/status'

# Repeat engagement: replaying a game, rewatching a film. An INSTANCE is one
# complete engagement with an item, from start to finish, and it is modelled as a
# CHILD ITEM (item.parent -> the catalog item) rather than a new type — so it keeps
# templates, custom fields, status and its own lifecycle for free. Its sessions are
# ordinary placements pointing at the child.
#
# This is the single seam that turns "I am doing this" into "an instance exists".
# It is called by the doors that already exist (staging, dating, the status edge into
# doing) rather than by a dedicated user action, the same way an occurrence
# materializes on first touch instead of being created. It is IDEMPOTENT: flipping to
# doing on Monday, staging on Tuesday and placing on Thursday resolves three times and
# mints once.
#
# For every item whose template does not opt in, this returns item_id unchanged — which
# is what lets the whole feature ship without altering any existing behavior.
def resolve_open_instance(item_id)
  item = Item.get(item_id)
  return item_id if item.nil?

  template_id = instance_template_for(item)
  return item_id if template_id.nil?

  open = open_instance_for(item)
  return open.id unless open.nil?

  mint_instance(item, template_id).id
end

# Which child template does this item's instances use, if any? The opt-in lives on the
# TEMPLATE (`attributes.instances.template`) and not on the list, because an item knows
# its own templates while finding its list means scanning every list — see
# item_has_shelf_home? in auto_archive.rb for that scan. Templates are stamped onto an
# item from the list it was added to, so "the Games list mints playthroughs" still falls
# out; it is just stored once on the template instead of once per list.
def instance_template_for(item)
  (item.templates || []).each do |template_id|
    template = Template.get(template_id)
    next if template.nil?

    config = (template.attributes || {})['instances']
    next unless config.is_a?(Hash)

    child_template = config['template']
    return child_template unless child_template.to_s.empty?
  end
  nil
end

# The one open instance, or nil. Open means "not in a terminal status" — an instance
# minted by staging sits at want-to until a session actually completes, so unstarted and
# in-progress are both open. AT MOST ONE may be open at a time: that invariant is what
# keeps a planner card unambiguous about which instance it belongs to.
def open_instance_for(item)
  (item.children || []).each do |child_id|
    child = Item.get(child_id)
    next if child.nil?
    next if Status.done?(child.json['status'])
    return child
  end
  nil
end

# Create a child instance and link it from the parent. Born at the default status
# (want-to) with no dates: minting is "this exists", not "this has begun". `started` is
# stamped later, by whichever door actually begins it — see stamp_instance_start below.
#
# `fields` lets the manual door (create_instance.rb) supply a status and dates for an
# instance that is being recorded after the fact.
def mint_instance(item, template_id, fields = {})
  template = Template.get(template_id)
  raise ListError::NotFound, "instance template '#{template_id}' not found" if template.nil?

  # No ordinal in the name. Creation order and chronological order agree right up until
  # you backfill a 2016 playthrough after playthrough 6 exists, and then the stored
  # number lies forever. The ledger numbers rows by date instead, which cannot drift.
  instance = Item.new({
    'name' => "#{item.name} — #{template.display_name}",
    'parent' => item.id,
    'templates' => [template_id],
  }.merge(fields))
  instance.validate
  instance.save!

  item.json['children'] = (item.children || []) + [instance.id]
  item.validate
  item.save!

  instance
end

# Record that a run has begun. Two doors call this and they disagree about the DATE,
# deliberately: a completed session uses the date it was planned for, so logging a week
# late still backdates the start correctly, while a manual flip to `doing` has no date
# but today.
#
# EARLIEST WINS, rather than first-writer-wins. Both doors can fire in either order —
# flip to `doing` today, then log the session you actually played last week — and a start
# that depended on which one happened to run first would be arbitrary. The earliest
# evidence that this run existed is the start, however late it was recorded.
#
# So re-flipping to `doing` never moves a start backwards in time, and a hand-corrected
# date survives every later session except one played earlier still.
def stamp_instance_start(instance, date)
  return instance if instance.nil? || date.to_s.empty?

  current = instance.json['started'].to_s
  return instance unless current.empty? || date < current

  instance.json['started'] = date
  instance.validate
  instance.save!
  instance
end
