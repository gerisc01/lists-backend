require 'date'

# A rule at `item.scheduling.recurrence`. It keeps one live occurrence per period; an untouched
# occurrence is computed (a "ghost") and becomes a Placement only once acted on.
#
#   scheduling.recurrence = {
#     'cadence'       => 'weekly',                 # 'weekly' or 'monthly'
#     'interval'      => 2,                         # every N weeks/months (positive Integer)
#     'mode'          => 'absolute',               # the only mode
#     'anchor'        => { 'kind' => 'floating' }, # see ANCHOR_KINDS_BY_CADENCE below
#     'collection_id' => 'c1',                     # whose staging the occurrence drains into
#     'active'        => true,                      # active/paused toggle (optional, default true)
#     'start_date'    => '2026-07-27',             # optional phase anchor for interval > 1
#     'end_date'      => '2026-08-31',             # optional; nothing after this week
#   }
class Recurrence

  CADENCES = %w[weekly monthly].freeze
  MODES    = %w[absolute].freeze

  # A monthly rule must say where in the month it lands, so `floating` is weekly-only.
  ANCHOR_KINDS_BY_CADENCE = {
    'weekly'  => %w[floating fixed-day],
    'monthly' => %w[date week-of-month],
  }.freeze

  def self.type_match?(value)
    return false if !value.is_a?(Hash)
    return false if !CADENCES.include?(value['cadence'])
    return false if !value['interval'].is_a?(Integer) || !value['interval'].positive?
    return false if !MODES.include?(value['mode'])
    return false if !value['collection_id'].is_a?(String) || value['collection_id'].empty?
    return false if !anchor_valid?(value['anchor'], value['cadence'])
    return false if !active_valid?(value['active'])
    return false if !date_valid?(value['start_date'])
    return false if !date_valid?(value['end_date'])
    return true
  end

  # nil means open-ended.
  def self.end_date_of(recurrence)
    return recurrence && recurrence['end_date']
  end

  # Absent means active; `false` pauses the rule.
  def self.active_of(recurrence)
    return true if recurrence.nil?
    recurrence.fetch('active', true) == true
  end

  def self.anchor_valid?(anchor, cadence)
    return false if !anchor.is_a?(Hash)
    kinds = ANCHOR_KINDS_BY_CADENCE[cadence]
    return false if kinds.nil? || !kinds.include?(anchor['kind'])

    return case anchor['kind']
    # Date#wday: 0 is Sunday.
    when 'fixed-day'    then day_in_range?(anchor['weekday'], 0..6)
    # A day past the month's end lands on its last day (occurrences.rb).
    when 'date'          then day_in_range?(anchor['day'], 1..31)
    # Week 5 lands on the month's last week.
    when 'week-of-month' then day_in_range?(anchor['week'], 1..5)
    else true
    end
  end

  def self.day_in_range?(value, range)
    return value.is_a?(Integer) && range.cover?(value)
  end

  def self.active_valid?(value)
    return value.nil? || [true, false].include?(value)
  end

  def self.date_valid?(value)
    return true if value.nil?
    begin
      # :: so it isn't SchemaType::Date.
      ::Date.parse(value.to_s)
      return true
    rescue ArgumentError, TypeError
      return false
    end
  end

end
