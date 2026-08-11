require 'date'

# A recurrence RULE on a catalog item (design.md §2.5). Recurrence is not a parent
# item that spawns pre-dated children (that is the legacy, now-dormant model — see
# dates_api.rb / date_helpers.rb); it is a rule that keeps ONE live occurrence
# present per period, materialized as a ghost and only persisted as a Placement once
# touched. The rule folds into the item's `scheduling` object rather than sprouting a
# second top-level field (see scheduling.rb, item.rb) — this is the same
# validation-type mechanism Status / Resolution / Scheduling use (`type_match?`), so
# the schema enforces the shape server-side.
#
#   scheduling.recurrence = {
#     'cadence'       => 'weekly',                 # 'weekly' or 'monthly'
#     'interval'      => 2,                         # every N weeks/months (positive Integer)
#     'mode'          => 'absolute',               # only absolute this slice
#     'anchor'        => { 'kind' => 'floating' }, # see ANCHOR_KINDS_BY_CADENCE below
#     'collection_id' => 'c1',                     # whose staging the occurrence drains into
#     'active'        => true,                      # active/paused toggle (optional, default true)
#     'start_date'    => '2026-07-27',             # optional phase anchor for interval > 1
#     'end_date'      => '2026-08-31',             # optional; no occurrences after this week (see occurrences.rb)
#   }
#
# `interval` is CADENCE-RELATIVE — weeks under weekly, months under monthly. One field,
# no schema branch; the unit is resolved by the cadence at read time and in the UI label.
#
# Scope: absolute weekly (floating + fixed-day) and absolute monthly (date + week-of-month).
# Relative cadence is deferred. `end_date` (bound a series going forward while preserving
# past placements) is supported. The constant arrays are the extension points — a later
# slice appends to them rather than restructuring.
class Recurrence

  CADENCES = %w[weekly monthly].freeze
  MODES    = %w[absolute].freeze

  # Cadence and anchor are NOT independent (design §2.5). Plain `floating` — "lands
  # dayless in the period, you pick the day" — is a weekly thing: a floating monthly
  # occurrence would have to answer "which week of the month?", so a monthly rule says
  # where it lands instead, by date ('the 3rd') or by week-of-month ('the 1st week').
  # This map is the single source of truth for both membership and compatibility.
  ANCHOR_KINDS_BY_CADENCE = {
    'weekly'  => %w[floating fixed-day],
    'monthly' => %w[date week-of-month],
  }.freeze

  def self.type_match?(value)
    return false unless value.is_a?(Hash)
    return false unless CADENCES.include?(value['cadence'])
    return false unless value['interval'].is_a?(Integer) && value['interval'].positive?
    return false unless MODES.include?(value['mode'])
    return false unless value['collection_id'].is_a?(String) && !value['collection_id'].empty?
    # After the cadence guard above, so the anchor is always checked against a known cadence.
    return false unless anchor_valid?(value['anchor'], value['cadence'])
    return false unless active_valid?(value['active'])
    return false unless date_valid?(value['start_date'])
    return false unless date_valid?(value['end_date'])
    true
  end

  # The optional upper bound: no occurrence is emitted after the week containing
  # end_date (design "clear the future" — see occurrences.rb). nil => open-ended.
  def self.end_date_of(recurrence)
    recurrence && recurrence['end_date']
  end

  # `active` is optional (absent => active); a paused rule sets it false and emits no
  # occurrences until resumed (design §2.5). Present => must be a boolean.
  def self.active_of(recurrence)
    return true if recurrence.nil?
    recurrence.fetch('active', true) == true
  end

  def self.anchor_valid?(anchor, cadence)
    return false unless anchor.is_a?(Hash)
    kinds = ANCHOR_KINDS_BY_CADENCE[cadence]
    return false if kinds.nil? || !kinds.include?(anchor['kind'])

    case anchor['kind']
    # fixed-day pins the occurrence to a weekday (Ruby Date#wday: 0=Sun..6=Sat).
    when 'fixed-day'    then day_in_range?(anchor['weekday'], 0..6)
    # date pins it to a day of the month. 31 is legal every month: an overflowing day
    # CLAMPS to the month's last (Feb gets the 28th) rather than skipping the period.
    when 'date'          then day_in_range?(anchor['day'], 1..31)
    # week-of-month is the same idea a week coarser: 5 is legal every month and clamps to
    # the month's last week. A month spans exactly 4 or 5 weeks, so only 5 ever clamps —
    # which makes week 5 mean "the last week" in every month.
    when 'week-of-month' then day_in_range?(anchor['week'], 1..5)
    else true # floating carries no shape of its own
    end
  end

  def self.day_in_range?(value, range)
    value.is_a?(Integer) && range.cover?(value)
  end

  def self.active_valid?(value)
    value.nil? || [true, false].include?(value)
  end

  # nil-allowed date validation, shared by start_date and end_date.
  def self.date_valid?(value)
    return true if value.nil?
    begin
      # :: prefix to avoid clashing with SchemaType::Date and friends.
      ::Date.parse(value.to_s)
      true
    rescue ArgumentError, TypeError
      false
    end
  end

end
