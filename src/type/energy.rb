# How much an item asks of you: mood for a film or game, effort for a task. Unlike status, the
# default is never stored — an unrated item has no `energy`, so read it through `of`.
class Energy

  VALUES  = %w[chill moderate intense].freeze
  DEFAULT = 'moderate'

  def self.type_match?(value)
    return VALUES.include?(value)
  end

  def self.of(value)
    return value || DEFAULT
  end

  def self.of_item(item)
    return of(item.json['energy'])
  end

end
