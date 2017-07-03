require "integration_test_helper"

class ElasticsearchIndexGroupTest < IntegrationTest
  def setup
    super

    @group_name = "mainstream_test"
    TestIndexHelpers.clean_index_group(@group_name)

    @index_group = search_server.index_group(@group_name)
  end

  def teardown
    # Making sure we keep the index after the tests run
    @index_group.create_index
  end

  def test_should_create_index
    assert @index_group.index_names.empty?
    index = @index_group.create_index

    assert_equal 1, @index_group.index_names.count
    assert_equal index.index_name, @index_group.index_names[0]
    assert_equal(
      app.settings.search_config.search_server.schema.elasticsearch_mappings("mainstream"),
      index.mappings
    )
  end

  def test_should_alias_index
    index = @index_group.create_index
    @index_group.switch_to(index)

    assert_equal index.real_name, @index_group.current.real_name
  end

  def test_should_switch_index
    old_index = @index_group.create_index
    @index_group.switch_to(old_index)

    new_index = @index_group.create_index
    @index_group.switch_to(new_index)

    assert_equal new_index.real_name, @index_group.current.real_name
  end

  def test_should_clean_indices
    @index_group.create_index
    @index_group.switch_to(@index_group.create_index)

    assert_equal 2, @index_group.index_names.count
    @index_group.clean
    assert_equal 1, @index_group.index_names.count
  end
end
