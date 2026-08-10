require_relative '../exceptions'
require_relative '../type/status'
require_relative '../type/energy'
require_relative './parser'

module Query

  # Walks a parsed AST against one item at a time.
  #
  # Every field resolves to a *list* of values, even the single-valued ones, so
  # one set of operator semantics covers them all. That matters most for `tag`,
  # where an item has many: `tag = Me` asks "does any tag match", and `tag != Me`
  # is its exact negation — "no tag matches", i.e. it isn't assigned to me. The
  # alternative (per-value comparison) makes `!=` mean "has some other tag too",
  # which is nearly always the wrong answer.
  #
  # A field with no values (an untagged item, an item in no collection) therefore
  # fails `=` and passes `!=`, which is what you want and is also why IS EMPTY
  # exists as its own operator: "untagged" is a real thing to search for.
  class Evaluator

    # Enum fields validate their operand. A typo'd `status = doig` would otherwise
    # return zero matches indistinguishably from "nothing matches", and this tool
    # exists precisely for the case where you can't find something.
    ENUMS = {
      'status' => Status::VALUES,
      'energy' => Energy::VALUES,
    }.freeze

    # `resolver` answers "what values does this item have for this field?" — it is
    # the only thing that knows about lists, collections and tag names, which keeps
    # this class free of storage concerns and trivially testable.
    def initialize(resolver)
      @resolver = resolver
    end

    def matches?(node, item)
      case node
      when And then matches?(node.left, item) && matches?(node.right, item)
      when Or then matches?(node.left, item) || matches?(node.right, item)
      when Not then !matches?(node.expr, item)
      when Condition then condition_matches?(node, item)
      else
        raise ListError::InternalServer, "Unknown query node #{node.class}"
      end
    end

    # Validates enum operands across the whole tree before evaluation, so a bad
    # value is a 400 rather than an empty result set. Separate from parsing
    # because the parser deliberately knows nothing about the domain's enums.
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
      nil
    end

    private

    def condition_matches?(condition, item)
      values = @resolver.values_for(condition.field, item)

      case condition.op
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
      actual.any? { |a| wanted.any? { |w| a.to_s.casecmp?(w.to_s) } }
    end

    def any_contains?(actual, needle)
      needle = needle.to_s.downcase
      actual.any? { |a| a.to_s.downcase.include?(needle) }
    end

  end

end
