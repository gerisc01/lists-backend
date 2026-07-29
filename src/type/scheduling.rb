# The planning kind of an item, for the one axis where events and tasks diverge:
# what "past" means (design.md §2.2). A small validation type (responds to
# `type_match?`) so the schema enforces the shape server-side, the same mechanism
# Status / SharingScope use — but here the field is an OBJECT, not a bare enum,
# because PR 12's recurrence rule folds into this same `scheduling` object rather
# than sprouting a second top-level field. See docs/DECISIONS.md "event/task lands
# as item.scheduling.type".
#
#   item.scheduling = { 'type' => 'event' | 'task' }
#
# Absent reads as `task` (§2.2: an unconsidered quick-add *persists*/carries rather
# than silently vanishing — the safe default; `event` is the deliberate opt-in for
# calendar anchors that resolve when their day passes).
require_relative './recurrence'

class Scheduling

  TYPES   = %w[event task].freeze
  DEFAULT = 'task'

  def self.type_match?(value)
    return false unless value.is_a?(Hash) && TYPES.include?(value['type'])
    # The optional recurrence rule folds into this same object (PR 12); when present
    # it must satisfy the Recurrence shape. Absent => a plain event/task, unchanged.
    return Recurrence.type_match?(value['recurrence']) if value.key?('recurrence')
    true
  end

  # The recurrence rule sub-object (nil/absent => not recurring).
  def self.recurrence_of(scheduling)
    return nil if scheduling.nil?
    scheduling['recurrence']
  end

  # Does this item carry a recurrence rule at all (active or paused)?
  def self.recurring?(item)
    !recurrence_of(item.json['scheduling']).nil?
  end

  # Does this item carry a rule that is currently emitting occurrences? A paused rule
  # (active: false) is recurring? but not active_recurrence? (design §2.5).
  def self.active_recurrence?(item)
    rule = recurrence_of(item.json['scheduling'])
    !rule.nil? && Recurrence.active_of(rule)
  end

  # The scheduling type for an item's raw `scheduling` value (nil/absent => DEFAULT).
  def self.type_of(scheduling)
    return DEFAULT if scheduling.nil?
    scheduling['type'] || DEFAULT
  end

  # Does this item's kind mean "past = resolved" (event) rather than "past carries"
  # (task)? Reads the item's stored scheduling, defaulting to task.
  def self.event?(item)
    type_of(item.json['scheduling']) == 'event'
  end

  def self.task?(item)
    type_of(item.json['scheduling']) == 'task'
  end

end
