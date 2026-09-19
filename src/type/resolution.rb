# How a placement was closed. No default: an open placement has no resolution.
class Resolution

  # `lapsed` is set only by reconcile, for a one-off whose week passed untouched; `skipped` is a choice.
  VALUES = %w[completed skipped lapsed].freeze

  def self.type_match?(value)
    return VALUES.include?(value)
  end

end
