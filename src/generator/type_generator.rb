require 'securerandom'
require_relative '../exceptions'

def setup_type_model(clazz)

  clazz.attr_accessor(:json)

  clazz.define_method(:initialize) do |json = nil|
    json = json.nil? ? {} : json
    json["id"] = SecureRandom.uuid if json["id"].nil?
    self.json = json
  end

  clazz.define_method(:validate) do
    schema = clazz.class_variable_get(:@@schema)
    schema.validate(self)
  end

  clazz.define_singleton_method(:from_object) do |json|
    clazz.new(json)
  end

  clazz.define_method(:to_object) do
    return self.json
  end

  clazz.define_method(:merge!) do |json|
    self.json = self.json.merge(json)
  end

  clazz.define_singleton_method(:set_db_class) do |clazz|
    clazz.instance_variable_set(:@@db, clazz)
  end

end

def define_get(clazz)
  clazz.define_singleton_method(:get) do |id|
    clazz::Database.get(id)
  end
end

def define_get_by_key(clazz)
  clazz.define_singleton_method(:get_by_key) do |key|
    matched = self.list().select { |obj| obj.json['key'] == key }
    return matched.empty? ? nil : matched[0]
  end
end

def define_exist?(clazz)
  clazz.define_singleton_method(:exist?) do |id|
    clazz::Database.get(id) != nil
  end
end

def define_list(clazz)
  clazz.define_singleton_method(:list) do
    clazz::Database.list
  end
end

def define_save!(clazz)
  clazz.define_method(:save!) do
    self.validate()
    clazz::Database.save(self)
  end
end

def define_delete!(clazz)
  clazz.define_method(:delete!) do
    raise ListError::BadRequest, "Invalid #{clazz}: id cannot be nil" if self.json['id'].to_s.empty?
    clazz::Database.delete(self.json['id'])
  end
end