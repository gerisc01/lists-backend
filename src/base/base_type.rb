class BaseType

  attr_accessor :json

  def initialize(json = nil)
    @json = json.nil? ? {} : json
    @json["id"] = SecureRandom.uuid if json["id"].nil?
  end

  def validate
    self.class.schema.validate(self)
  end

  def self.from_object(json)
    return self.new(json)
  end

  def to_object
    return @json
  end

  def merge!(json)
    @json = @json.merge(json)
  end

  ## TODO: Find a way to selectively import these, but for now just have all the accessors turned on by default 
  
  def self.get(id)
    return self::Database.get(id)
  end

  def self.get_by_key(key)
    matched = self.list().select { |obj| obj.json['key'] == key }
    return matched.empty? ? nil : matched[0]
  end

  def self.exist?(id)
    self::Database.get(id) != nil
  end
  
  def self.list
    self::Database.list
  end

  def save!
    self.validate
    self.class::Database.save(self)
  end

  def delete!
    raise ListError::BadRequest, "Invalid #{self.class.to_s}: id cannot be nil" if self.json['id'].to_s.empty?
    self.class::Database.delete(self.json['id'])
  end

end