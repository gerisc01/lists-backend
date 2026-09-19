require 'time'

class Status

  VALUES  = %w[want-to doing on-hold completed retired].freeze
  DEFAULT = 'want-to'

  TERMINAL = %w[completed retired].freeze

  def self.type_match?(value)
    return VALUES.include?(value)
  end

  def self.done?(value)
    return TERMINAL.include?(value)
  end

end

# One entry in `item.transitions`: `{from, to, at, by?}`. `by` is the account that made the change
# (not who did the work — that's `placement.resolved_by`), and is absent when no person acted.
class Transition

  def self.type_match?(value)
    return value.is_a?(Hash) &&
      Status::VALUES.include?(value['to']) &&
      (value['from'].nil? || Status::VALUES.include?(value['from'])) &&
      value['at'].is_a?(String) &&
      (value['by'].nil? || value['by'].is_a?(String))
  end

  def self.build(from:, to:, by: nil)
    entry = { 'from' => from, 'to' => to, 'at' => Time.now.utc.iso8601 }
    entry['by'] = by if !by.nil?
    return entry
  end

end
