require 'securerandom'
require 'json'

class BaseService

  attr_reader :id
  @loaded_objs = nil

  def initialize()
    @id = SecureRandom.uuid
  end

  def self.loaded_objs
    @loaded_objs
  end

  def self.file_name
    @file_name
  end

  def self.get(id)
    list if @loaded_objs == nil
    return @loaded_objs[id]
  end
  
  def self.list
    @loaded_objs = load()
    return @loaded_objs.values
  end
  
  def self.create(clazzObj)
    raise "Input isn't a type of #{self.to_s.inspect}" if !clazzObj.is_a?(self)
    raise "Can't save an object with no id" if clazzObj.nil? || clazzObj.id == nil
    list if @loaded_objs == nil
    raise "#{self.to_s.inspect} object already exists with id #{clazzObj.id}" if @loaded_objs.has_key?(clazzObj.id)
    @loaded_objs[clazzObj.id] = clazzObj.to_hash
    save(@loaded_objs.to_json)
    return @loaded_objs[clazzObj.id]
  end

  def self.load
    return File.exist?(@file_name) ? JSON.parse(File.read(@file_name)) : {}
  end

  def self.save(json)
    File.write(@file_name, json)
  end

  def to_hash
    hash = {}
    self.instance_variables.each do |var|
      hash[var.to_s.delete("@")] = self.instance_variable_get(var)
    end
    return hash
  end

  def to_json
    return to_hash().to_json
  end

end