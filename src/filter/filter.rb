require_relative '../exceptions.rb'
require_relative '../type/collection'
require_relative '../type/list'
require_relative '../type/item'

class Filter

  def self.find_matching_items(collection_id, filter)
    # Only use json representation to speed up filtering
    # Right now relying on caching to keep things quick
    collection = Collection.get(collection_id)
    lists = collection.json['lists'].map { |list_id| List.get(list_id).json }
    lists.each { |json| json['items'] = json.has_key?('items') ? json['items'].map { |item_id| Item.get(item_id).json } : [] }

    result = evaluate_filter(filter, lists)
    return result
  end

  def self.evaluate_filter(filter, lists)
    result = []
    # Deal with parens (only works with single for now)
    paren_groups = filter.scan(/\(.*?\)/)
    f = filter.gsub(/\(.*?\)/, "$PAREN_GROUP")
    # Split into individual statements
    all_expr = f.split(/ (AND|OR) /)
    operators = []
    expressions = []
    all_expr.each_slice(2) do |expr, op|
      expressions.push(expr)
      operators.push(op) if !op.nil?
    end
    # Evaluate each expressions (including dealing with paren groups as the token is found)
    matching_ids = expressions.map { |expr| evaluate_expression(expr, paren_groups, lists) }
    operators.each_with_index do |op, idx|
      if op == "AND"
        # Intersection of ids (AND)
        result = result == [] ? matching_ids[idx] & matching_ids[idx+1] : result & matching_ids[idx+1]
      elsif op == "OR"
        # Union of ids (OR)
        result = result == [] ? matching_ids[idx] | matching_ids[idx+1] : result | matching_ids[idx+1]
      else
        raise ListError::BadRequest, "Invalid operator '#{op}'. Must be 'OR' or 'AND'."
      end
    end
    return matching_ids[0] if operators == [] && matching_ids.size == 1
    return result
  end

  def self.evaluate_expression(expression, paren_groups, lists)
    tokenize = expression.split(/(=|<|>|!=)/).map! { |it| it.strip }
    type,field_path = dot_notation_parse(tokenize[0])
    item_ids = []
    if type == 'list'
      matched_lists = retrieve_matching(lists, field_path, tokenize[1], tokenize[2], paren_groups)
      item_ids = matched_lists.flat_map { |json| json['items'].map { |item| item['id'] } }
    elsif type == 'item'
      items = lists.flat_map { |json| json['items'] }
      matched_items = retrieve_matching(items, field_path, tokenize[1], tokenize[2], paren_groups)
      item_ids = matched_items.map { |item| item['id'] }
    else
      raise ListError::BadRequest, "Filter expression '#{type}' not valid. Must be 'list' or 'item'."
    end
    return item_ids
  end

  def self.retrieve_matching(objs, field_path, operator, value, paren_groups)
    matched = []
    if value != '$PAREN_GROUP'
      matched = objs.filter { |obj| match(get_by_dot_notation(obj, field_path), operator, value) }
    else
      paren = paren_groups.slice!(0)[1..-1]
      if paren.include?(' OR ') && paren.include?(' AND ')
        raise ListError::BadRequest, "Can't mix AND and OR expressions in one () block"
      elsif paren.include?(' OR ')
        parts = paren.split(' OR ').map! { |it| it.strip }
        matched = objs.filter { |obj| parts.any? { |value| match(get_by_dot_notation(obj, field_path), operator, value) } }
      elsif paren.include?(' AND ')
        raise ListError::BadRequest, "Currently don't support AND expressions inside of () blocks"
      end
    end
    return matched
  end

  def self.match(left, operator, right)
    if operator == "="
      return left.to_s.downcase == right.to_s.downcase
    elsif operator == "!="
      return left.to_s.downcase != right.to_s.downcase
    elsif operator == ">"
      return left.to_s.downcase > right.to_s.downcase
    elsif operator == "<"
      return left.to_s.downcase < right.to_s.downcase
    else
      raise ListError::BadRequest, "Invalid operator '#{operator}"
    end
  end

  def self.dot_notation_parse(dot_str)
    dot = dot_str.split(".")
    return [dot.slice!(0), dot]
  end

  def self.get_by_dot_notation(hash, fields)
    return hash if fields.nil? || fields.empty?
    new_hash = hash[fields.slice(0)]
    get_by_dot_notation(new_hash, fields[1..])
  end

end