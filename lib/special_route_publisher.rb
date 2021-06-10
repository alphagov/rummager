require "gds_api/publishing_api"
require "gds_api/publishing_api/special_route_publisher"

class SpecialRoutePublisher
  def initialize(publisher_options)
    @publisher = GdsApi::PublishingApi::SpecialRoutePublisher.new(publisher_options)
  end

  def take_ownership_of_search_routes
    publishing_api = GdsApi::PublishingApi.new(
      Plek.new.find("publishing-api"),
      bearer_token: ENV["PUBLISHING_API_BEARER_TOKEN"] || "example",
    )
    %w[/search /search.json /search/opensearch.xml].each do |path|
      publishing_api.put_path(
        path,
        publishing_app: "search-api",
        override_existing: true,
      )
    end
  end

  def publish(route)
    @publisher.publish(
      route.merge(
        publishing_app: "search-api",
        format: "special_route",
        public_updated_at: Time.now.iso8601,
        update_type: "major",
      ),
    )
  end

  def routes
    [
      {
        rendering_app: "finder-frontend",
        content_id: "84e0909c-f3e6-43ee-ba68-9e33213a3cdd",
        base_path: "/search",
        title: "GOV.UK search results",
        description: "Sitewide search results are displayed here.",
        document_type: "search",
        type: "exact",
      },
      {
        rendering_app: "finder-frontend",
        content_id: "9f306cd5-1842-43e9-8408-2c13116f4717",
        base_path: "/search.json",
        title: "GOV.UK search results API",
        description: "Sitewide search results are displayed in JSON format here.",
        type: "exact",
      },
      {
        rendering_app: "finder-frontend",
        content_id: "3df77dea-00c5-43f0-8f31-d08b8bd2a4d6",
        base_path: "/search/advanced",
        title: "Latest on GOV.UK",
        description: "Sitewide search results with advanced filtering are displayed here.",
        type: "exact",
      },
      {
        rendering_app: "finder-frontend",
        content_id: "ba750368-8001-4d01-bd57-cec589153fdd",
        base_path: "/search/opensearch.xml",
        title: "GOV.UK opensearch descriptor",
        description: "Provides the location and format of our search URL to browsers etc.",
        type: "exact",
      },
      {
        rendering_app: "search-api",
        content_id: "0818867d-8026-482c-b797-306fb74f5a2d",
        base_path: "/api/search.json",
        title: "GOV.UK search results API",
        description: "Sitewide search results are displayed in JSON format here.",
        type: "exact",
      },
      {
        rendering_app: "search-api",
        content_id: "5edd25bd-987f-45d3-8eca-5fb35cbf2978",
        base_path: "/api/batch_search.json",
        title: "GOV.UK batch search results API",
        description: "Sitewide batch search results are displayed in JSON format here.",
        type: "exact",
      },
      {
        rendering_app: "search-api",
        base_path: "/sitemap.xml",
        content_id: "fee32a90-397a-4761-9f98-b06e47d2b798",
        title: "GOV.UK sitemap index",
        description: "Provides the locations of the GOV.UK sitemaps.",
        type: "exact",
      },
      {
        rendering_app: "search-api",
        base_path: "/sitemaps",
        content_id: "c202c6a5-656c-40d1-ae55-36fab995709c",
        title: "GOV.UK sitemaps prefix",
        description: "The prefix URL under which our XML sitemaps are located.",
        type: "prefix",
      },
    ]
  end
end
