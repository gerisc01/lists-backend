require_relative '../schema/schema'
require_relative '../generator/type_generator'

class Template

  @@schema = Schema.new
  @@schema.key = "template"
  @@schema.display_name = "Template"
  @@schema.fields = {
    "id" => {:required => true, :type => String, :display_name => 'Id'},
    "key" => {:required => false, :type => String, :display_name => 'Key'},
    "name" => {:required => true, :type => String, :display_name => 'Name'}
  }
  @@schema.apply_schema(self)

  setup_type_model(self)

end