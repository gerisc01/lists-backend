require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../../src/schema/schema'
require_relative '../../src/template/template'

class SchemaTest < Minitest::Test

  class TypeTestClass
    attr_accessor :json

    @@schema = Schema.new
    @@schema.key = "test-schema"
    @@schema.display_name = "Test Schema"
    @@schema.fields = {
      "key" => {:required => false, :type => String, :display_name => 'Key'},
      "length" => {:required => false, :type => Integer, :display_name => 'Length'},
      "finished" => {:required => false, :type => SchemaType::Date, :display_name => 'Finished'},
      "replay" => {:required => false, :type => SchemaType::Boolean, :display_name => 'Replay'},
      "lists" => {:required => false, :type => Array, :display_name => 'Lists'},
      "templates" => {:required => false, :type => Hash, :display_name => 'Templates'}
    }
    @@schema.apply_schema(self)

    def initialize(json = nil)
      @json = json.nil? ? {} : json
    end

    def self.get_schema
      return @@schema
    end
  end

  def setup
  end

  def teardown
  end

  ## Test different types

  def test_schema_string
    gc = TypeTestClass.new({"key" => "12345"})
    TypeTestClass.get_schema.validate(gc)
  end

  def test_schema_integer
    gc = TypeTestClass.new({"length" => 12345})
    TypeTestClass.get_schema.validate(gc)
  end

  def test_schema_boolean
    gc = TypeTestClass.new({"replay" => true})
    TypeTestClass.get_schema.validate(gc)
    gc = TypeTestClass.new({"replay" => false})
    TypeTestClass.get_schema.validate(gc)
  end

  def test_schema_date
    gc = TypeTestClass.new({"finished" => "2022-05-19"})
    TypeTestClass.get_schema.validate(gc)
    gc = TypeTestClass.new({"finished" => Date.new(2022, 5, 19)})
    TypeTestClass.get_schema.validate(gc)
  end

end