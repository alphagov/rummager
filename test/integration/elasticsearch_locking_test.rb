require "integration_test_helper"

class ElasticsearchLockingTest < IntegrationTest

  def setup
    stub_elasticsearch_settings
    enable_test_index_connections
    try_remove_test_index
  end

  def teardown
    clean_index_group
  end

  def test_should_fail_to_insert_when_index_locked
    create_test_index

    index = search_server.index_group(@default_index_name).current
    index.lock
    assert_raises Elasticsearch::IndexLocked do
      index.add([sample_document])
    end
  end

  def test_should_fail_to_amend_when_index_locked
    create_test_index

    index = search_server.index_group(@default_index_name).current
    index.add([sample_document])
    index.lock
    assert_raises Elasticsearch::IndexLocked do
      index.amend(sample_document.link, "title" => "New title")
    end
  end

  def test_should_fail_to_delete_when_index_locked
    create_test_index

    index = search_server.index_group(@default_index_name).current
    index.add([sample_document])
    index.lock
    assert_raises Elasticsearch::IndexLocked do
      index.delete(sample_document.link)
    end
  end

  def test_should_unlock_index
    create_test_index

    index = search_server.index_group(@default_index_name).current
    index.lock
    index.unlock
    index.add([sample_document])
  end
end
