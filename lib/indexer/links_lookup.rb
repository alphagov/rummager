require 'services'
require 'govuk_taxonomy_helpers'

# LinksLookup finds the tags (links) from the publishing-api and merges them into
# the document. If there aren't any links, the payload will be returned unchanged.
module Indexer
  class PublishingApiError < StandardError; end

  class LinksLookup
    def initialize
      @logger = Logging.logger[self]
    end

    def self.prepare_tags(doc_hash)
      new.prepare_tags(doc_hash)
    end

    def prepare_tags(doc_hash)
      # Rummager contains externals links (that have a full URL in the `link`
      # field). These won't have tags associated with them so we can bail out.
      return doc_hash if doc_hash["link"] =~ /\Ahttps?:\/\//

      # Bail out if the base_path doesn't exist in publishing-api
      content_id = find_content_id(doc_hash)
      return doc_hash unless content_id

      content_item = {
        "content_id" => content_id,
        "base_path" => doc_hash["link"],
        "title" => doc_hash["title"],
        "details" => {},
      }

      # Bail out if the base_path doesn't exist in publishing-api
      expanded_links_response = find_links(content_id)
      return doc_hash unless expanded_links_response

      doc_hash = doc_hash.merge(taggings_with_slugs(expanded_links_response))
      doc_hash.merge(taggings_with_content_ids(expanded_links_response, content_item))
    end

  private

    # Some applications send the `content_id` for their items. This means we can
    # skip the lookup from the publishing-api.
    def find_content_id(doc_hash)
      if doc_hash["content_id"].present?
        doc_hash["content_id"]
      else
        begin
          GdsApi.with_retries(maximum_number_of_attempts: 5) do
            Services.publishing_api.lookup_content_id(base_path: doc_hash["link"])
          end
        rescue GdsApi::TimedOutException => e
          @logger.error("Timeout looking up content ID for #{doc_hash['link']}")
          Airbrake.notify_or_ignore(e,
            error_message: "Timeout looking up content ID",
            parameters: {
              base_path: doc_hash["link"]
            }
          )
          raise Indexer::PublishingApiError
        rescue GdsApi::HTTPErrorResponse => e
          @logger.error("HTTP error looking up content ID for #{doc_hash['link']}: #{e.message}")
          # We capture all GdsApi HTTP exceptions here so that we can send them
          # manually to Airbrake. This allows us to control the message and parameters
          # such that errors are grouped in a sane manner.
          Airbrake.notify_or_ignore(e,
            error_message: "HTTP error looking up content ID",
            parameters: {
              base_path: doc_hash["link"],
              error_code: e.code,
              error_message: e.message,
              error_details: e.error_details
            }
          )
          raise Indexer::PublishingApiError
        end
      end
    end

    def find_links(content_id)
      begin
        GdsApi.with_retries(maximum_number_of_attempts: 5) do
          Services.publishing_api.get_expanded_links(content_id)
        end
      rescue GdsApi::TimedOutException => e
        @logger.error("Timeout fetching expanded links for #{content_id}")
        Airbrake.notify_or_ignore(e,
          error_message: "Timeout fetching expanded links",
          parameters: {
            content_id: content_id
          }
        )
        raise Indexer::PublishingApiError
      rescue GdsApi::HTTPErrorResponse => e
        @logger.error("HTTP error fetching expanded links for #{content_id}: #{e.message}")
        # We capture all GdsApi HTTP exceptions here so that we can send them
        # manually to Airbrake. This allows us to control the message and parameters
        # such that errors are grouped in a sane manner.
        Airbrake.notify_or_ignore(e,
          error_message: "HTTP error fetching expanded links",
          parameters: {
            content_id: content_id,
            error_code: e.code,
            error_message: e.message,
            error_details: e.error_details
          }
        )
        raise Indexer::PublishingApiError
      end
    end

    # Documents in rummager currently reference topics, browse pages and
    # organisations by "slug", a concept that exists in Publisher and Whitehall.
    # It does not exist in the publishing-api, so we need to infer the slug
    # from the base path.
    def taggings_with_slugs(expanded_links_response)
      links = expanded_links_response['expanded_links']
      links_with_slugs = {}

      # We still call topics "specialist sectors" in rummager.
      links_with_slugs["specialist_sectors"] = links["topics"].to_a.map do |content_item|
        content_item['base_path'].sub('/topic/', '')
      end

      links_with_slugs["mainstream_browse_pages"] = links["mainstream_browse_pages"].to_a.map do |content_item|
        content_item['base_path'].sub('/browse/', '')
      end

      links_with_slugs["organisations"] = links["organisations"].to_a.map do |content_item|
        content_item['base_path'].sub('/government/organisations/', '').sub('/courts-tribunals/', '')
      end

      links_with_slugs["taxons"] = content_ids_for(links, 'taxons')

      links_with_slugs
    end

    def taggings_with_content_ids(expanded_links_response, content_item)
      links = expanded_links_response['expanded_links']

      {
        'topic_content_ids' => content_ids_for(links, 'topics'),
        'mainstream_browse_page_content_ids' => content_ids_for(links, 'mainstream_browse_pages'),
        'organisation_content_ids' => content_ids_for(links, 'organisations'),
        'part_of_taxonomy_tree' => parts_of_taxonomy(expanded_links_response, content_item)
      }
    end

    def parts_of_taxonomy(expanded_links, content_item)
      linked_content_item = GovukTaxonomyHelpers::LinkedContentItem.from_publishing_api(
        content_item: content_item,
        expanded_links: expanded_links
      )
      linked_content_item.taxons_with_ancestors.map(&:content_id)
    end

    def content_ids_for(links, link_type)
      links[link_type].to_a.map do |content_item|
        content_item['content_id']
      end
    end
  end
end
