require 'json'
require_relative '../exceptions'

def file_based_db_and_cache(dbClazz, typeClazz)
  self.class_variable_set(:@@mutex, Mutex.new)
  self.class_variable_set(:@@loaded_objs, nil)

  dbClazz.define_singleton_method(:cache_loaded?) do
    return !self.class_variable_get(:@@loaded_objs).nil?
  end

  dbClazz.define_singleton_method(:cache_clear) do
    self.class_variable_set(:@@loaded_objs, nil)
  end

  dbClazz.define_singleton_method(:file_load) do
    file_name = self.class_variable_get(:@@file_name)
    File.exist?(file_name) ? JSON.parse(File.read(file_name)) : {}
  end

  dbClazz.define_singleton_method(:load) do
    mutex = self.class_variable_get(:@@mutex)
    mutex.synchronize do
      json = self.file_load()
      self.class_variable_set(:@@loaded_objs, {})
      loaded_objs = self.class_variable_get(:@@loaded_objs)
      json.each do |id, json|
        loaded_objs[id] = typeClazz.from_object(json)
      end
    end
  end

  dbClazz.define_singleton_method(:file_write) do |persist_objs|
    file_name = self.class_variable_get(:@@file_name)
    Dir.mkdir('data') if !Dir.exist?('data')
    File.write(file_name, persist_objs.to_json)
  end

  dbClazz.define_singleton_method(:persist) do
    mutex = self.class_variable_get(:@@mutex)
    mutex.synchronize do
      loaded_objs = self.class_variable_get(:@@loaded_objs)
      if loaded_objs.nil?
        self.file_write({})
        return
      end

      persist_objs = {}
      loaded_objs.each do |id, obj|
        persist_objs[id] = obj.to_object
      end
      self.file_write(persist_objs)
    end
  end
end

def define_db_get(clazz)
  clazz.define_singleton_method(:get) do |id|
    self.load unless self.cache_loaded?()
    loaded_objs = self.class_variable_get(:@@loaded_objs)
    return loaded_objs[id]
  end
end

def define_db_list(clazz)
  clazz.define_singleton_method(:list) do
    self.load unless self.cache_loaded?()
    loaded_objs = self.class_variable_get(:@@loaded_objs)
    return loaded_objs.values
  end
end

def define_db_save(clazz)
  clazz.define_singleton_method(:save) do |obj|
    self.load unless self.cache_loaded?()
    loaded_objs = self.class_variable_get(:@@loaded_objs)
    loaded_objs[obj.json['id']] = obj
    self.persist()
  end
end

def define_db_delete(clazz)
  clazz.define_singleton_method(:delete) do |id|
    self.load unless self.cache_loaded?()
    loaded_objs = self.class_variable_get(:@@loaded_objs)
    loaded_objs.delete(id)
    self.persist()
  end
end