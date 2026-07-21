# Who can access a list/collection. A small validation type (responds to
# `type_match?`) so the schema enforces the enum server-side, the same mechanism
# Status / SchemaType::Boolean use. Structural only — the unit of sharing is the
# collection/list (design §6.1); no sharing/invite/permissions UI reads it yet.
class SharingScope

  # `public` is deliberately omitted — there is no anonymous-access concept. It
  # can be added here later without a migration (absent reads as DEFAULT).
  VALUES  = %w[private shared].freeze
  DEFAULT = 'private'

  def self.type_match?(value)
    VALUES.include?(value)
  end

end
