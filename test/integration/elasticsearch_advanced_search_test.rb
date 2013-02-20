require "integration_test_helper"
require "app"
require "rest-client"

class ElasticsearchAdvancedSearchTest < IntegrationTest

  def setup
    use_elasticsearch_for_primary_search

    schema = deep_copy(settings.elasticsearch_schema)
    properties = schema["mappings"]["default"]["edition"]["properties"]
    properties.merge!({"boolean_property" => { "type" => "boolean", "index" => "not_analyzed" },
                       "date_property" => { "type" => "date", "index" => "not_analyzed" }})
    app.settings.stubs(:elasticsearch_schema).returns(schema)

    WebMock.disable_net_connect!(allow: "localhost:9200")
    reset_elasticsearch_index
    add_sample_documents
    commit_index
  end

  def sample_document_attributes
    [
      {
        "title" => "Cheese in my face",
        "description" => "Hummus weevils",
        "format" => "answer",
        "link" => "/an-example-answer",
        "indexable_content" => "I like my badger: he is tasty and delicious",
        "boolean_property" => true,
        "date_property" => "2012-01-01"
      },
      {
        "title" => "Useful government information",
        "description" => "Government, government, government. Developers.",
        "format" => "answer",
        "link" => "/another-example-answer",
        "section" => "Crime",
        "indexable_content" => "Tax, benefits, roads and stuff",
        "boolean_property" => false,
        "date_property" => "2012-01-03"
      },
      {
        "title" => "Cheesey government information",
        "description" => "Government, government, government. Developers.",
        "format" => "answer",
        "link" => "/yet-another-example-answer",
        "section" => "Crime",
        "indexable_content" => "Tax, benefits, roads and stuff, mostly about cheese",
        "boolean_property" => true,
        "date_property" => "2012-01-04"
      },
      {
        "title" => "Pork pies",
        "link" => "/pork-pies",
        "boolean_property" => true,
        "date_property" => "2012-01-02"
      }
    ]
  end

  def add_sample_documents
    sample_document_attributes.each do |sample_document|
      post "/documents", MultiJson.encode(sample_document)
      assert last_response.ok?
    end
  end

  def commit_index
    post "/commit", nil
  end

  def assert_result_links(*links)
    parsed_response = MultiJson.decode(last_response.body)
    assert_equal links, parsed_response['results'].map { |r| r["link"] }
  end

  def assert_result_total(total)
    parsed_response = MultiJson.decode(last_response.body)
    assert_equal total, parsed_response['total']
  end

  def test_should_search_by_keywords
    get "/primary/advanced_search.json?per_page=1&page=1&keywords=cheese"
    assert last_response.ok?
    assert_result_total 2
    assert_result_links "/an-example-answer"
  end

  def test_should_allow_paging_through_keyword_search
    get "/primary/advanced_search.json?per_page=1&page=2&keywords=cheese"
    assert last_response.ok?
    assert_result_total 2
    assert_result_links "/yet-another-example-answer"
  end

  def test_should_filter_results_by_a_property
    get "/primary/advanced_search.json?per_page=2&page=1&section=Crime"
    assert last_response.ok?
    assert_result_total 2
    assert_result_links "/another-example-answer", "/yet-another-example-answer"
  end

  def test_should_allow_boolean_filtering
    get "/primary/advanced_search.json?per_page=3&page=1&boolean_property=true"
    assert last_response.ok?
    assert_result_total 3
    assert_result_links "/an-example-answer", "/yet-another-example-answer", "/pork-pies"
  end

  def test_should_allow_date_filtering
    get "/primary/advanced_search.json?per_page=3&page=1&date_property[before]=2012-01-03"
    assert last_response.ok?
    assert_result_total 3
    assert_result_links "/an-example-answer", "/another-example-answer", "/pork-pies"
  end

  def test_should_allow_combining_all_filters
    # add another doc to make the filter combination need everything to pick
    # the one we want
    more_documents = [
      {
        "title" => "Government cheese",
        "description" => "Government, government, government. cheese.",
        "format" => "answer",
        "link" => "/cheese-example-answer",
        "section" => "Crime",
        "indexable_content" => "Cheese tax.  Cheese recipies.  Cheese music.",
        "boolean_property" => true,
        "date_property" => "2012-01-01"
      }
    ]
    (more_documents).each do |sample_document|
      post "/documents", MultiJson.encode(sample_document)
      assert last_response.ok?
    end
    commit_index


    get "/primary/advanced_search.json?per_page=3&page=1&boolean_property=true&date_property[after]=2012-01-02&keywords=tax&section=Crime"
    assert last_response.ok?
    assert_result_total 1
    assert_result_links "/yet-another-example-answer"
  end

  def test_should_allow_ordering_by_properties
    get "/primary/advanced_search.json?per_page=4&page=1&order[date_property]=desc"
    assert last_response.ok?
    assert_result_total 4
    assert_result_links "/yet-another-example-answer", "/another-example-answer", "/pork-pies", "/an-example-answer"
  end
end
