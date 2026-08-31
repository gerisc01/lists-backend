# The scheduling object on an item. Today it holds exactly one thing: the recurrence
# rule (§2.5). A small validation type (responds to `type_match?`) so the schema enforces
# the shape server-side, the same mechanism Status / SharingScope use.
#
#   item.scheduling = { 'recurrence' => { … } }
#
# It USED to carry an event/task kind, which decided what "past" meant: an event's day
# passing resolved its placement, a task's did not. That was deleted on 2026-08-31 —
# see decision 0076. Two facts killed it: no surface ever wrote `event` (the only two
# writers of `scheduling` in the app default it to `task` and preserve it thereafter), and
# nothing should ever be marked done without the user saying so. A `type` key left in
# stored data is inert and still validates, so no migration was needed.
require_relative './recurrence'

class Scheduling

  def self.type_match?(value)
    return false unless value.is_a?(Hash)
    # The optional recurrence rule folds into this same object (PR 12); when present
    # it must satisfy the Recurrence shape. Absent => a scheduling object with nothing
    # in it yet, which is fine: the field is optional all the way down.
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

end
