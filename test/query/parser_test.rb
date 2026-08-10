require_relative '../minitest_wrapper'
require_relative '../../src/query/parser'

class QueryParserTest < MinitestWrapper

  def parse(input)
    Query::Parser.parse(input)
  end

  def cond(field, op, *values)
    Query::Condition.new(field, op, values)
  end

  def test_a_single_condition
    assert_equal cond('status', :eq, 'doing'), parse('status = doing')
  end

  def test_all_binary_operators
    assert_equal cond('name', :ne, 'x'), parse('name != x')
    assert_equal cond('name', :contains, 'paint'), parse('name ~ paint')
    assert_equal cond('name', :not_contains, 'paint'), parse('name !~ paint')
  end

  def test_quoted_values_keep_spaces_and_case
    assert_equal cond('name', :contains, 'light switch'), parse('name ~ "light switch"')
    assert_equal cond('tag', :eq, 'Me'), parse("tag = 'Me'")
  end

  # A tag genuinely named "not" would otherwise lex as a keyword.
  def test_quoting_escapes_a_keyword_used_as_a_value
    assert_equal cond('tag', :eq, 'not'), parse('tag = "not"')
  end

  def test_keywords_are_case_insensitive
    assert_equal parse('status = doing AND energy = chill'),
                 parse('status = doing and energy = chill')
  end

  # The dot-notation spelling the older filter module used still parses.
  def test_item_prefix_is_accepted_and_normalized_away
    assert_equal cond('status', :eq, 'doing'), parse('item.status = doing')
  end

  def test_and_binds_tighter_than_or
    # a OR (b AND c) — NOT (a OR b) AND c, which is what a left-to-right fold gives
    ast = parse('status = doing OR energy = chill AND tag = me')
    assert_instance_of Query::Or, ast
    assert_equal cond('status', :eq, 'doing'), ast.left
    assert_instance_of Query::And, ast.right
    assert_equal cond('energy', :eq, 'chill'), ast.right.left
    assert_equal cond('tag', :eq, 'me'), ast.right.right
  end

  def test_parens_override_precedence
    ast = parse('(status = doing OR energy = chill) AND tag = me')
    assert_instance_of Query::And, ast
    assert_instance_of Query::Or, ast.left
    assert_equal cond('tag', :eq, 'me'), ast.right
  end

  def test_nested_parens_to_arbitrary_depth
    ast = parse('((status = doing OR (energy = chill AND tag = me)) OR name ~ x)')
    assert_instance_of Query::Or, ast
  end

  def test_not_binds_tighter_than_and
    ast = parse('NOT status = doing AND energy = chill')
    assert_instance_of Query::And, ast
    assert_instance_of Query::Not, ast.left
    assert_equal cond('energy', :eq, 'chill'), ast.right
  end

  def test_not_applies_to_a_group
    ast = parse('NOT (status = doing OR status = completed)')
    assert_instance_of Query::Not, ast
    assert_instance_of Query::Or, ast.expr
  end

  def test_in_and_not_in
    assert_equal cond('status', :in, 'want-to', 'doing'), parse('status IN (want-to, doing)')
    assert_equal cond('status', :not_in, 'completed'), parse('status NOT IN (completed)')
  end

  def test_is_empty_and_is_not_empty
    assert_equal cond('tag', :empty), parse('tag IS EMPTY')
    assert_equal cond('tag', :not_empty), parse('tag IS NOT EMPTY')
  end

  def test_whitespace_is_insignificant
    assert_equal parse('status=doing AND energy=chill'),
                 parse('  status   =  doing   AND   energy = chill  ')
  end

  # --- errors: the point is a usable message, not just a rejection ---

  def test_empty_query_is_rejected
    assert_raises(ListError::BadRequest) { parse('   ') }
  end

  def test_unknown_field_names_the_valid_ones
    error = assert_raises(ListError::BadRequest) { parse('colour = red') }
    assert_includes error.message, 'colour'
    assert_includes error.message, 'status'
  end

  def test_unclosed_paren_is_rejected
    assert_raises(ListError::BadRequest) { parse('(status = doing') }
  end

  def test_unterminated_quote_is_rejected
    assert_raises(ListError::BadRequest) { parse('name ~ "paint') }
  end

  def test_trailing_junk_is_rejected
    assert_raises(ListError::BadRequest) { parse('status = doing energy = chill') }
  end

  def test_missing_operator_is_rejected
    assert_raises(ListError::BadRequest) { parse('status doing') }
  end

  def test_missing_value_is_rejected
    assert_raises(ListError::BadRequest) { parse('status =') }
  end

end
