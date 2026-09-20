require_relative '../exceptions'

# The item search language, e.g.
#   energy = chill AND status != completed
#   NOT (collection = Recipes) AND tag IS EMPTY
#
# NOT binds tighter than AND, and AND tighter than OR:
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

  # Keywords, field names and values all match case-insensitively.
  KEYWORDS = %w[AND OR NOT IN IS EMPTY].freeze

  Token = Struct.new(:type, :value, :pos)

  # Data only; Query::Evaluator does the matching.
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

        # Quotes allow spaces, or a value that is also a keyword ("not").
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

        # Dots allow `item.status`; dashes allow `want-to`.
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
      return tokens
    end

  end

  class Parser

    # Here so a misspelled field fails at parse time and lists the valid ones.
    FIELDS = %w[name status energy tag collection list].freeze

    def self.parse(input)
      raise ListError::BadRequest, 'Query is empty' if input.to_s.strip.empty?
      parser = new(Lexer.tokenize(input))
      ast = parser.send(:parse_or)
      parser.send(:expect_eof)
      return ast
    end

    def initialize(tokens)
      @tokens = tokens
      @pos = 0
    end

    private

    def peek
      return @tokens[@pos]
    end

    def advance
      token = @tokens[@pos]
      @pos += 1
      return token
    end

    def keyword?(word)
      return peek.type == :keyword && peek.value == word
    end

    def accept_keyword(word)
      return false if !keyword?(word)
      advance
      return true
    end

    def expect_eof
      return if peek.type == :eof
      raise ListError::BadRequest,
            "Unexpected '#{peek.value}' at position #{peek.pos} — expected AND, OR, or end of query"
    end

    def parse_or
      node = parse_and
      node = Or.new(node, parse_and) while accept_keyword('OR')
      return node
    end

    def parse_and
      node = parse_unary
      node = And.new(node, parse_unary) while accept_keyword('AND')
      return node
    end

    def parse_unary
      return Not.new(parse_unary) if accept_keyword('NOT')
      return parse_primary
    end

    def parse_primary
      if peek.type == :lparen
        advance
        node = parse_or
        if peek.type != :rparen
          raise ListError::BadRequest, "Missing ')' — unclosed group at position #{peek.pos}"
        end
        advance
        return node
      end
      return parse_condition
    end

    def parse_condition
      token = advance
      if token.type != :value
        raise ListError::BadRequest,
              "Expected a field name at position #{token.pos}, got '#{token.value || 'end of query'}'"
      end

      field = token.value.sub(/\Aitem\./i, '').downcase
      if !FIELDS.include?(field)
        raise ListError::BadRequest,
              "Unknown field '#{field}'. Valid fields: #{FIELDS.join(', ')}"
      end

      if accept_keyword('IS')
        negated = accept_keyword('NOT')
        if !accept_keyword('EMPTY')
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
        if !accept_keyword('IN')
          raise ListError::BadRequest, "Expected IN after NOT at position #{peek.pos}"
        end
        return Condition.new(field, :not_in, parse_value_list)
      end

      op_token = advance
      if op_token.type != :operator
        raise ListError::BadRequest,
              "Expected an operator after '#{field}' at position #{op_token.pos}, got '#{op_token.value || 'end of query'}'"
      end
      op = { '=' => :eq, '!=' => :ne, '~' => :contains, '!~' => :not_contains }[op_token.value]

      value_token = advance
      if value_token.type != :value
        raise ListError::BadRequest,
              "Expected a value after '#{op_token.value}' at position #{value_token.pos}"
      end

      return Condition.new(field, op, [value_token.value])
    end

    def parse_value_list
      if peek.type != :lparen
        raise ListError::BadRequest, "Expected '(' after IN at position #{peek.pos}"
      end
      advance

      values = []
      loop do
        token = advance
        if token.type != :value
          raise ListError::BadRequest, "Expected a value inside IN (...) at position #{token.pos}"
        end
        values << token.value
        break if peek.type != :comma
        advance
      end

      if peek.type != :rparen
        raise ListError::BadRequest, "Missing ')' closing IN (...) at position #{peek.pos}"
      end
      advance

      return values
    end

  end

end
