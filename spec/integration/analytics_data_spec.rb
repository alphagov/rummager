require 'spec_helper'

RSpec.describe 'AnalyticsDataTest', tags: ['integration'] do
  allow_elasticsearch_connection(scroll: true)

  before do
    @analytics_data_fetcher = AnalyticsData.new(SearchConfig.instance.base_uri, ["mainstream_test"])
  end

  it "fetches_rows_of_analytics_dimensions" do
    document = {
      "content_id" => "587b0635-2911-49e6-af68-3f0ea1b07cc5",
      "link" => "/an-example-page",
      "title" => "some page title",
      "content_store_document_type" => "some_document_type",
      "primary_publishing_organisation" => %w(some_publishing_org),
      "organisations" => %w(some_org another_org yet_another_org),
      "navigation_document_supertype" => "some_navigation_supertype",
      "user_journey_document_supertype" => "some_user_journey_supertype",
      "public_timestamp" => "2017-06-20T10:21:55.000+01:00",
    }
    commit_document("mainstream_test", document)

    rows = @analytics_data_fetcher.rows

    expected_row = [
        "587b0635-2911-49e6-af68-3f0ea1b07cc5",
        "/an-example-page",
        "some_publishing_org",
        nil,
        "some page title",
        "some_document_type",
        "some_navigation_supertype",
        nil,
        "some_user_journey_supertype",
        "some_org, another_org, yet_another_org",
        "20170620",
        nil,
        nil,
      ]

    assert_equal [expected_row], rows.to_a
  end

  it "missing_data_is_nil" do
    document = {}
    id = commit_document("mainstream_test", document)

    rows = @analytics_data_fetcher.rows

    expected_row = [id, id, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]

    assert_equal [expected_row], rows.to_a
  end

  it "content_id_is_preferred_to_link_for_product_id" do
    document = {
      "content_id" => "some_content_id",
      "link" => "/some/page/path",
    }
    commit_document("mainstream_test", document)

    rows = @analytics_data_fetcher.rows

    assert_equal "some_content_id", rows.first[0]
  end

  it "product_id_falls_back_to_link_if_content_id_is_missing" do
    document = {
      "link" => "/some/page/path",
    }
    commit_document("mainstream_test", document)

    rows = @analytics_data_fetcher.rows

    assert_equal "/some/page/path", rows.first[0]
  end

  it "document_type_is_preferred_to_format" do
    document = {
      "format" => "some_format",
      "content_store_document_type" => "some_document_type",
    }
    commit_document("mainstream_test", document)

    rows = @analytics_data_fetcher.rows

    assert_equal "some_document_type", rows.first[5]
  end

  it "document_type_falls_back_to_format_if_not_present" do
    document = {
      "format" => "some_format",
    }
    commit_document("mainstream_test", document)

    rows = @analytics_data_fetcher.rows

    assert_equal "some_format", rows.first[5]
  end

  it "sanitises_unix_line_breaks_in_titles" do
    document = {
      "title" => <<~HEREDOC
        A page title
        with some
        line breaks
        HEREDOC
    }
    commit_document("mainstream_test", document)

    rows = @analytics_data_fetcher.rows

    assert_equal "A page title with some line breaks", rows.first[4]
  end

  it "sanitises_windows_line_breaks_in_titles" do
    document = {
      "title" => "A page title\r\nwith some\r\nline breaks"
    }
    commit_document("mainstream_test", document)

    rows = @analytics_data_fetcher.rows

    assert_equal "A page title with some line breaks", rows.first[4]
  end

  it "fetches_all_rows" do
    fixture_file = File.expand_path("../fixtures/content_for_analytics.json", __FILE__)
    documents = JSON.parse(File.read(fixture_file))
    documents.each do |document|
      commit_document("mainstream_test", document)
    end

    analytics_data = @analytics_data_fetcher.rows.to_a

    assert_equal 30, analytics_data.size
  end

  it "headers_and_rows_are_consisent" do
    document = {
      "content_id" => "587b0635-2911-49e6-af68-3f0ea1b07cc5",
      "link" => "/an-example-page",
      "popularity": 0.5,
    }
    commit_document("mainstream_test", document)

    rows = @analytics_data_fetcher.rows
    headers = @analytics_data_fetcher.headers

    assert_equal headers.size, rows.first.size
  end
end
