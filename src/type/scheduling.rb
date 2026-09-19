# `item.scheduling = { 'recurrence' => { … } }`. Stored rows may also have a `type` key, which
# nothing reads.
require_relative './recurrence'

class Scheduling

  def self.type_match?(value)
    return false if !value.is_a?(Hash)
    return Recurrence.type_match?(value['recurrence']) if value.key?('recurrence')
    return true
  end

  def self.recurrence_of(scheduling)
    return nil if scheduling.nil?
    return scheduling['recurrence']
  end

  # True for a paused rule too.
  def self.recurring?(item)
    !recurrence_of(item.json['scheduling']).nil?
  end

  def self.active_recurrence?(item)
    rule = recurrence_of(item.json['scheduling'])
    return !rule.nil? && Recurrence.active_of(rule)
  end

end
