require_relative '../exceptions'

# A small JQL-shaped query language over catalog items.
#
#   energy = chill AND status != completed
#   tag = "Me" AND (energy = chill OR name ~ paint)
#   NOT (collection = Recipes) AND tag IS EMPTY
#   status IN (want-to, doing) AND name ~ "light switch"
#
# Why a hand-written lexer + recursive-descent parser rather than extending the
# existing `src/filter/filter.rb`: that module splits on regexes, which caps it at
# a single level of parens, forbids AND inside them, has no NOT, and — the real
# problem — folds mixed AND/OR left-to-right, so `a OR b AND c` silently means
# `(a OR b) AND c`. Precedence and arbitrary nesting are the whole point of the
# feature, and neither is reachable from that design. (That module is unreferenced
# by any route or client; see docs/DECISIONS.md.)
#
# The grammar, lowest precedence first — NOT binds tighter than AND, which binds
# tighter than OR, matching SQL/JQL and ordinary reading:
#
#   query     := or_expr
#   or_expr   := and_expr (OR and_expr)*
#   and_expr  := unary (AND unary)*
#   unary     := NOT unary | primary
#   primary   := '(' or_expr ')' | condition
#   condition := FIELD ('=' | '!=' | '~' | '!~') value
#              | FIELD ('IN' | 'NOT IN') '(' value (',' value)* ')'
#              | FIELD 'IS' ['NOT'] 'EMPTY'
#   value     := QUOTED | BAREWORD
module Query

  # Keywords are matched case-insensitively (`and` == `AND`), like JQL. Field
  # names and values compare case-insensitively too — this is a find-my-stuff
  # tool, and making people match case is a way to hand back zero results.
  KEYWORDS = %w[AND OR NOT IN IS EMPTY].freeze

  Token = Struct.new(:type, :value, :pos)

  # AST nodes. Deliberately data-only — evaluation lives in Query::Evaluator so a
  # parse can be tested (and later compiled to something else) without touching
  # the item store.
  And = Struct.new(:left, :right)
  Or = Struct.new(:left, :right)
  Not = Struct.new(:expr)
  # `op` is one of :eq, :ne, :contains, :not_contains, :in, :not_in, :empty, :not_empty.
  # `values` is always an array (empty for the IS EMPTY forms).
  Condition = Struct.new(:field, :op, :values)

  class Lexer

    # Longest-first so `!=` never lexes as `!` + `=`.
    SYMBOLS = ['!=', '!~', '=', '~', '(', ')', ','].freeze

    def self.tokenize(input)
      tokens = []
      pos = 0
      chars = input.to_s

      while pos < chars.length
        char = chars[pos]

        if char =~ /\s/
          pos += 1
          next
        end

        # Quoted values: the escape hatch for anything with spaces ("light switch")
        # or a word that would otherwise lex as a keyword (a tag literally named
        # "not").
        if char == '"' || char == "'"
          quote = char
          closing = chars.index(quote, pos + 1)
          raise ListError::BadRequest, "Unterminated quote starting at position #{pos}" if closing.nil?
          tokens << Token.new(:value, chars[(pos + 1)...closing], pos)
          pos = closing + 1
          next
        end

        symbol = SYMBOLS.find { |s| chars[pos, s.length] == s }
        if symbol
          type = case symbol
                 when '(' then :lparen
                 when ')' then :rparen
                 when ',' then :comma
                 else :operator
                 end
          tokens << Token.new(type, symbol, pos)
          pos += symbol.length
          next
        end

        # A bareword: a field name, a keyword, or an unquoted value. Dots are
        # allowed so the older `item.status` spelling still parses (normalized
        # away in the parser); dashes matter for `want-to` and `on-hold`.
        if char =~ /[\w\-.\/]/
          start = pos
          pos += 1 while pos < chars.length && chars[pos] =~ /[\w\-.\/]/
          word = chars[start...pos]
          type = KEYWORDS.include?(word.upcase) ? :keyword : :value
          tokens << Token.new(type, type == :keyword ? word.upcase : word, start)
          next
        end

        raise ListError::BadRequest, "Unexpected character '#{char}' at position #{pos}"
      end

      tokens << Token.new(:eof, nil, chars.length)
      tokens
    end

  end

  class Parser

    # The fields a condition may name. Kept here rather than in the evaluator so
    # a typo fails at parse time with the valid set in the message — silently
    # returning zero results is the worst outcome for a tool whose job is finding
    # things you've lost.
    FIELDS = %w[name status energy tag collection list].freeze

    def self.parse(input)
      raise ListError::BadRequest, 'Query is empty' if input.to_s.strip.empty?
      parser = new(Lexer.tokenize(input))
      ast = parser.send(:parse_or)
      parser.send(:expect_eof)
      ast
    end

    def initialize(tokens)
      @tokens = tokens
      @pos = 0
    end

    private

    def peek
      @tokens[@pos]
    end

    def advance
      token = @tokens[@pos]
      @pos += 1
      token
    end

    def keyword?(word)
      peek.type == :keyword && peek.value == word
    end

    def accept_keyword(word)
      return false unless keyword?(word)
      advance
      true
    end

    def expect_eof
      return if peek.type == :eof
      raise ListError::BadRequest,
            "Unexpected '#{peek.value}' at position #{peek.pos} — expected AND, OR, or end of query"
    end

    def parse_or
      node = parse_and
      node = Or.new(node, parse_and) while accept_keyword('OR')
      node
    end

    def parse_and
      node = parse_unary
      node = And.new(node, parse_unary) while accept_keyword('AND')
      node
    end

    def parse_unary
      return Not.new(parse_unary) if accept_keyword('NOT')
      parse_primary
    end

    def parse_primary
      if peek.type == :lparen
        advance
        node = parse_or
        unless peek.type == :rparen
          raise ListError::BadRequest, "Missing ')' — unclosed group at position #{peek.pos}"
        end
        advance
        return node
      end
      parse_condition
    end

    def parse_condition
      token = advance
      if token.type != :value
        raise ListError::BadRequest,
              "Expected a field name at position #{token.pos}, got '#{token.value || 'end of query'}'"
      end

      # `item.status` and `status` are the same field — the older dot-notation
      # spelling keeps working, but the prefix carries no meaning: every field is
      # item-scoped because every result is an item.
      field = token.value.sub(/\Aitem\./i, '').downcase
      unless FIELDS.include?(field)
        raise ListError::BadRequest,
              "Unknown field '#{field}'. Valid fields: #{FIELDS.join(', ')}"
      end

      if accept_keyword('IS')
        negated = accept_keyword('NOT')
        unless accept_keyword('EMPTY')
          raise ListError::BadRequest, "Expected EMPTY after IS at position #{peek.pos}"
        end
        return Condition.new(field, negated ? :not_empty : :empty, [])
      end

      if keyword?('IN')
        advance
        return Condition.new(field, :in, parse_value_list)
      end

      if keyword?('NOT')
        advance
        unless accept_keyword('IN')
          raise ListError::BadRequest, "Expected IN after NOT at position #{peek.pos}"
        end
        return Condition.new(field, :not_in, parse_value_list)
      end

      op_token = advance
      unless op_token.type == :operator
        raise ListError::BadRequest,
              "Expected an operator after '#{field}' at position #{op_token.pos}, got '#{op_token.value || 'end of query'}'"
      end
      op = { '=' => :eq, '!=' => :ne, '~' => :contains, '!~' => :not_contains }[op_token.value]

      value_token = advance
      unless value_token.type == :value
        raise ListError::BadRequest,
              "Expected a value after '#{op_token.value}' at position #{value_token.pos}"
      end

      Condition.new(field, op, [value_token.value])
    end

    def parse_value_list
      unless peek.type == :lparen
        raise ListError::BadRequest, "Expected '(' after IN at position #{peek.pos}"
      end
      advance

      values = []
      loop do
        token = advance
        unless token.type == :value
          raise ListError::BadRequest, "Expected a value inside IN (...) at position #{token.pos}"
        end
        values << token.value
        break unless peek.type == :comma
        advance
      end

      unless peek.type == :rparen
        raise ListError::BadRequest, "Missing ')' closing IN (...) at position #{peek.pos}"
      end
      advance

      values
    end

  end

end
