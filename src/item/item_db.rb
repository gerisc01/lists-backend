class ItemDb

  @@file_name = "items.json"
  @@loaded_objs = nil ## When initialized, is a {}

  def self.cache_loaded?
    return !@@loaded_objs.nil?
  end

  def self.cache_clear
    @@loaded_objs = nil
  end

  def self.file_load
    File.exist?(@@file_name) ? JSON.parse(File.read(@@file_name)) : {}
  end

  def self.load
    json = file_load()
    @@loaded_objs = {}
    json.each do |id, json|
      @@loaded_objs[id] = Item.from_object(json)
    end
  end

  def self.persist
    persist_objs = {}
    @@loaded_objs.each do |id, item|
      persist_objs[id] = item.to_object
    end
    File.write(@@file_name, persist_objs.to_json)
  end

  def self.get(id)
    load unless cache_loaded?()
    return @@loaded_objs[id]
  end

  def self.list
    load unless cache_loaded?()
    @@loaded_objs.values
  end

  def self.save(item)
    load unless cache_loaded?()
    @@loaded_objs[item.id] = item
    persist()
  end

  def self.delete(id)
    load unless cache_loaded?()
    @@loaded_objs.delete(id)
    persist()
  end

end