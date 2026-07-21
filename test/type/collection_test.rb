require_relative '../minitest_wrapper'
require_relative '../helpers'
require_relative '../../src/type/collection'

class CollectionTest < MinitestWrapper

  def setup
    @collection = Collection.new({'name' => 'Test Collection'})
  end

  def test_collection_sharing_scope_valid
    @collection.sharing_scope = 'shared'
    assert_equal 'shared', @collection.sharing_scope
    @collection.validate

    @collection.sharing_scope = 'private'
    assert_equal 'private', @collection.sharing_scope
    @collection.validate
  end

  def test_collection_sharing_scope_absent
    assert_nil @collection.sharing_scope
    @collection.validate
  end

  def test_collection_sharing_scope_invalid_rejected
    assert_raises(Schema::ValidationError) do
      @collection.sharing_scope = 'bogus'
    end
  end

  def test_collection_sharing_scope_persist
    @collection.sharing_scope = 'shared'
    @collection.save!

    reloaded = Collection.get(@collection.id)
    assert_equal 'shared', reloaded.sharing_scope
  end

end
