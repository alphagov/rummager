require_relative "../../test_helper"
require "health_check/logging_config"
require "health_check/json_search_client"
Logging.logger.root.appenders = nil

module HealthCheck
  class JsonSearchClientTest < ShouldaUnitTestCase
    def search_response_body
      {
        "results" => [
          {
            "link" => "/a"
          },
          {
            "link" => "/b"
          }
        ],
        "suggested_queries" => %w(
A
B)
      }
    end

    def stub_search(search_term, custom_headers = {})
      stub_request(:get, "http://www.gov.uk/api/search.json?q=#{CGI.escape(search_term)}").
        with(headers: { 'Accept' => '*/*', 'User-Agent' => 'Ruby' }.merge(custom_headers)).
        to_return(status: 200, body: search_response_body.to_json)
    end

    should "support the search format" do
      stub_search("cheese")
      expected = { results: ["/a", "/b"], suggested_queries: %w[A B] }
      base_url = URI.parse("http://www.gov.uk/api/search.json")

      assert_equal expected, JsonSearchClient.new(base_url: base_url).search("cheese")
    end

    should "call the search API with a rate limit token if provided" do
      stub_search("cheese", "Rate-Limit-Token" => "some_token")

      expected = { results: ["/a", "/b"], suggested_queries: %w[A B] }
      base_url = URI.parse("http://www.gov.uk/api/search.json")

      response = JsonSearchClient.new(base_url: base_url, rate_limit_token: "some_token").search("cheese")

      assert_equal expected, response
    end
  end
end
