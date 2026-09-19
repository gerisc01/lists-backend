# Stored on a collection; nothing on the server enforces it.
class SharingScope

  VALUES  = %w[private shared].freeze
  DEFAULT = 'private'

  def self.type_match?(value)
    return VALUES.include?(value)
  end

end
