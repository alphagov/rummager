require "json"
require "transport/client"
require_relative "multivalue_converter"

module LegacyClient
  class IndexForSearch
    attr_reader :index_names, :schema

    # How long to wait between reads when streaming data from the elasticsearch server
    TIMEOUT_SECONDS = 5.0

    # How long to wait for a connection to the elasticsearch server
    OPEN_TIMEOUT_SECONDS = 5.0

    def initialize(base_uri, index_names, schema, search_config)
      @index_uri = base_uri + "#{CGI.escape(index_names.join(","))}/"
      @client = build_client
      @index_names = index_names
      @schema = schema
      @search_config = search_config
    end

    def raw_search(payload, type = nil)
      json_payload = payload.to_json
      logger.debug "Request payload: #{json_payload}"
      if type.nil?
        path = "_search"
      else
        path = "#{type}/_search"
      end
      @client.get_with_payload(path, json_payload)
    end

    def get_document_by_link(link)
      results = raw_search(query: { term: { link: link } }, size: 1)
      raw_result = results['hits']['hits'].first

      if raw_result
        raw_result['real_index_name'] = SearchIndices::Index.strip_alias_from_index_name(raw_result['_index'])
      end

      raw_result
    end

    def msearch(bodies)
      header_json = "{}"
      payload = bodies.map { |body|
        "#{header_json}\n#{body.to_json}\n"
      }.join("")
      logger.debug "Request payload: #{payload}"
      path = "_msearch"
      @client.get_with_payload(path, payload)
    end

    def documents_by_format(format, field_definitions)
      batch_size = 500
      search_body = {
        query: { term: { format: format } },
        fields: field_definitions.keys,
      }

      ScrollEnumerator.new(@client, search_body, batch_size) do |hit|
        MultivalueConverter.new(hit["fields"], field_definitions).converted_hash
      end
    end

  private

    def logger
      Logging.logger[self]
    end

    def build_client(options = {})
      Transport::Client.new(
        @index_uri,
        timeout: options[:timeout] || TIMEOUT_SECONDS,
        open_timeout: options[:open_timeout] || OPEN_TIMEOUT_SECONDS
      )
    end
  end
end
