require_relative '../exceptions'
require_relative '../type/status'
require_relative '../type/energy'
require_relative './parser'

module Query

  # Every field resolves to a list of values, so `tag != Me` means "no tag is Me", and an item with no
  # values fails `=` and passes `!=`.
  class Evaluator

    # A misspelled enum value (`status = doig`) is a 400, not an empty result.
    ENUMS = {
      'status' => Status::VALUES,
      'energy' => Energy::VALUES,
    }.freeze

    # `resolver` returns an item's values for a field (Search's CatalogIndex).
    def initialize(resolver)
      @resolver = resolver
    end

    def matches?(node, item)
      return case node
      when And then matches?(node.left, item) && matches?(node.right, item)
      when Or then matches?(node.left, item) || matches?(node.right, item)
      when Not then !matches?(node.expr, item)
      when Condition then condition_matches?(node, item)
      else
        raise ListError::InternalServer, "Unknown query node #{node.class}"
      end
    end

    # Checked here, not in the parser, which doesn't know the enums.
    def validate!(node)
      case node
      when And, Or
        validate!(node.left)
        validate!(node.right)
      when Not
        validate!(node.expr)
      when Condition
        allowed = ENUMS[node.field]
        return if allowed.nil?
        node.values.each do |value|
          next if allowed.any? { |v| v.casecmp?(value) }
          raise ListError::BadRequest,
                "'#{value}' is not a valid #{node.field}. Valid values: #{allowed.join(', ')}"
        end
      end
      return nil
    end

    private

    def condition_matches?(condition, item)
      values = @resolver.values_for(condition.field, item)

      return case condition.op
      when :empty then values.empty?
      when :not_empty then values.any?
      when :eq then any_equal?(values, condition.values)
      when :ne then !any_equal?(values, condition.values)
      when :in then any_equal?(values, condition.values)
      when :not_in then !any_equal?(values, condition.values)
      when :contains then any_contains?(values, condition.values.first)
      when :not_contains then !any_contains?(values, condition.values.first)
      else
        raise ListError::InternalServer, "Unknown operator #{condition.op}"
      end
    end

    def any_equal?(actual, wanted)
      return actual.any? { |a| wanted.any? { |w| a.to_s.casecmp?(w.to_s) } }
    end

    def any_contains?(actual, needle)
      needle = needle.to_s.downcase
      return actual.any? { |a| a.to_s.downcase.include?(needle) }
    end

  end

end
