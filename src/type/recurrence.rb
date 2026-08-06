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
#     'cadence'       => 'weekly',                 # only weekly this slice
#     'interval'      => 2,                         # every N weeks (positive Integer)
#     'mode'          => 'absolute',               # only absolute this slice
#     'anchor'        => { 'kind' => 'floating' }, # OR { 'kind' => 'fixed-day', 'weekday' => 0..6 }
#     'collection_id' => 'c1',                     # whose staging the occurrence drains into
#     'active'        => true,                      # active/paused toggle (optional, default true)
#     'start_date'    => '2026-07-27',             # optional phase anchor for interval > 1
#     'end_date'      => '2026-08-31',             # optional; no occurrences after this week (see occurrences.rb)
#   }
#
# Scope (PR 12): absolute weekly, floating + fixed-day anchoring. Relative cadence and
# monthly/date/week-phase anchoring are deferred. `end_date` (bound a series going
# forward while preserving past placements) is supported. The constant arrays are the
# extension points — a later slice appends to them rather than restructuring.
class Recurrence

  CADENCES     = %w[weekly].freeze
  MODES        = %w[absolute].freeze
  ANCHOR_KINDS = %w[floating fixed-day].freeze

  def self.type_match?(value)
    return false unless value.is_a?(Hash)
    return false unless CADENCES.include?(value['cadence'])
    return false unless value['interval'].is_a?(Integer) && value['interval'].positive?
    return false unless MODES.include?(value['mode'])
    return false unless value['collection_id'].is_a?(String) && !value['collection_id'].empty?
    return false unless anchor_valid?(value['anchor'])
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

  def self.anchor_valid?(anchor)
    return false unless anchor.is_a?(Hash)
    return false unless ANCHOR_KINDS.include?(anchor['kind'])
    # fixed-day pins the occurrence to a weekday (Ruby Date#wday: 0=Sun..6=Sat).
    if anchor['kind'] == 'fixed-day'
      return anchor['weekday'].is_a?(Integer) && (0..6).cover?(anchor['weekday'])
    end
    true
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
