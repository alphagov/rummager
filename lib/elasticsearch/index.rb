require "document"
require "logging"
require "cgi"
require "rest-client"
require "multi_json"
require "json"
require "elasticsearch/advanced_search_query_builder"
require "elasticsearch/client"
require "elasticsearch/index_queue"
require "elasticsearch/escaping"
require "elasticsearch/result_set"
require "elasticsearch/scroll_enumerator"
require "elasticsearch/search_query_builder"
require "result_promoter"

module Elasticsearch
  class InvalidQuery < ArgumentError; end
  class DocumentNotFound < RuntimeError; end

  class BulkIndexFailure < RuntimeError
    attr_reader :failed_keys

    def initialize(failed_keys)
      super "Failed inserts: #{failed_keys.join(', ')}"
      @failed_keys = failed_keys
    end
  end

  class Index
    include Elasticsearch::Escaping

    # An enumerator with a manually-specified size.
    # This means we can count the number of documents in an index without
    # having to load them all.
    class SizedEnumerator < Enumerator
      attr_reader :size

      def initialize(size, &block)
        super(&block)
        @size = size
      end
    end

    # The number of documents to insert at once when populating
    def self.populate_batch_size
      50
    end

    # The number of documents to retrieve at once when retrieving all documents
    # Gotcha: this is actually the number of documents per shard, so there will
    # be up to some multiple of this number per page.
    def self.scroll_batch_size
      50
    end

    # How long to hold a scroll cursor open between requests
    # We should be able to keep this low, since these are only for internal use
    SCROLL_TIMEOUT_MINUTES = 1

    # How long to wait between reads when streaming data from the elasticsearch server
    TIMEOUT_SECONDS = 5.0

    # How long to wait for a connection to the elasticsearch server
    OPEN_TIMEOUT_SECONDS = 5.0

    attr_reader :mappings, :index_name, :promoted_results

    def initialize(base_uri, index_name, mappings, promoted_results = [])
      @client = Client.new(
        base_uri + "#{CGI.escape(index_name)}/",
        timeout: TIMEOUT_SECONDS,
        open_timeout: OPEN_TIMEOUT_SECONDS
      )
      @index_name = index_name
      raise ArgumentError, "Missing index_name parameter" unless @index_name
      @mappings = mappings
      @promoted_results = promoted_results
    end

    def field_names
      @mappings["edition"]["properties"].keys
    end

    def real_name
      alias_info = MultiJson.decode(@client.get("_aliases"))
      # If the index exists, it will return something of the form:
      # { real_name => { "aliases" => { alias => {} } } }
      # If not, it'll return:
      # {}
      alias_info.keys.first
    end

    def exists?
      ! real_name.nil?
    end

    def add(documents)
      if documents.size == 1
        logger.info "Adding #{documents.size} document to #{index_name}"
      else
        logger.info "Adding #{documents.size} documents to #{index_name}"
      end

      document_hashes = documents.map { |d| hash_from_document(d) }
      bulk_index(document_hashes)
    end

    # Add documents asynchronously to the index.
    def add_queued(documents)
      noun = documents.size > 1 ? "documents" : "document"
      logger.info "Queueing #{documents.size} #{noun} to add to #{index_name}"

      document_hashes = documents.map { |d| hash_from_document(d) }
      queue.queue_many(document_hashes)
    end

    def bulk_index(document_hashes)
      response = @client.post("_bulk", bulk_payload(document_hashes), content_type: :json)
      items = MultiJson.decode(response.body)["items"]
      failed_items = items.select { |item| item["index"].has_key?("error") }
      if failed_items.any?
        raise BulkIndexFailure.new(failed_items.map { |item| item["index"]["_id"] })
      end
      response
    end

    def amend(link, updates)
      document = get(link)
      raise DocumentNotFound.new(link) unless document

      if updates.include? "link"
        raise ArgumentError.new("Cannot change document links")
      end

      updates.each do |key, value|
        if document.has_field?(key)
          document.set key, value
        else
          raise ArgumentError.new("Unrecognised field '#{key}'")
        end
      end
      add [document]
      return true
    end

    def amend_queued(link, updates)
      queue.queue_amend(link, updates)
    end

    def populate_from(source_index)
      total_indexed = 0
      all_docs = source_index.all_documents
      all_docs.each_slice(self.class.populate_batch_size) do |documents|
        add documents
        total_indexed += documents.length
        logger.info do
          progress = "#{total_indexed}/#{all_docs.size}"
          source_name = source_index.index_name
          "Populated #{progress} from #{source_name} into #{index_name}"
        end
      end

      commit
    end

    def get(link)
      logger.info "Retrieving document with link '#{link}'"
      begin
        response = @client.get("_all/#{CGI.escape(link)}")
      rescue RestClient::ResourceNotFound
        return nil
      end

      document_from_hash(MultiJson.decode(response.body)["_source"])
    end

    def document_from_hash(hash)
      Document.from_hash(hash, @mappings)
    end

    def all_documents
      # Set off a scan query to get back a scroll ID and result count
      search_body = {query: {match_all: {}}}
      batch_size = self.class.scroll_batch_size
      ScrollEnumerator.new(@client, search_body, batch_size) do |hit|
        document_from_hash(hit["_source"])
      end
    end

    def all_document_links(exclude_formats = [])
      search_body = {
        "query" => {
          "bool" => {
            "must_not" => {
              "terms" => {
                "format" => exclude_formats
              }
            }
          }
        },
        "fields" => ["link"]
      }

      batch_size = self.class.scroll_batch_size
      ScrollEnumerator.new(@client, search_body, batch_size) do |hit|
        hit["fields"]["link"]
      end
    end

    # `options` can have the following keys:
    #   :fields - a list of field names to be included in the document, if not
    #             specified, the mappings are used.
    def documents_by_format(format, options = {})
      batch_size = 500
      search_body = {query: {term: {format: format}}}
      if options[:fields]
        search_body.merge!(fields: options[:fields])
        field_names = options[:fields]
        result_key = "fields"
      else
        # Use all field names from the mappings
        # TODO: remove duplication between this and Document.from_hash
        field_names = @mappings["edition"]["properties"].keys.map(&:to_s)
        result_key = "_source"
      end

      ScrollEnumerator.new(@client, search_body, batch_size) do |hit|
        Document.new(field_names, hit[result_key])
      end
    end

    def search(keywords, options={})
      builder = SearchQueryBuilder.new(keywords, @mappings, options)
      raise InvalidQuery.new(builder.error) unless builder.valid?

      payload = MultiJson.dump(builder.query_hash)
      logger.debug "Request payload: #{payload}"
      response = @client.get_with_payload("_search", payload)
      ResultSet.new(@mappings, MultiJson.decode(response))
    end

    def advanced_search(params)
      logger.info "params:#{params.inspect}"
      if params["per_page"].nil? || params["page"].nil?
        raise InvalidQuery.new("Pagination params are required.")
      end

      # Delete params that we don't want to be passed as filter_params
      order     = params.delete("order")
      keywords  = params.delete("keywords")
      per_page  = params.delete("per_page").to_i
      page      = params.delete("page").to_i

      query_builder = AdvancedSearchQueryBuilder.new(keywords, params, order, @mappings)
      raise InvalidQuery.new(query_builder.error) unless query_builder.valid?

      starting_index = page <= 1 ? 0 : (per_page * (page - 1))
      payload = {
        "from" => starting_index,
        "size" => per_page
      }

      payload.merge!(query_builder.query_hash)

      logger.info "Request payload: #{payload.to_json}"

      result = @client.get_with_payload("_search", payload.to_json)
      ResultSet.new(@mappings, MultiJson.decode(result))
    end

    def delete(link)
      begin
        # Can't use a simple delete, because we don't know the type
        @client.delete "_query", params: {q: "link:#{escape(link)}"}
      rescue RestClient::ResourceNotFound
      end
      return true  # For consistency with the Solr API and simple_json_response
    end

    def delete_queued(link)
      queue.queue_delete(link)
    end

    def delete_all
      @client.delete_with_payload("_query", {match_all: {}}.to_json)
      commit
    end

    def commit
      @client.post "_refresh", nil
    end

    private
    def logger
      Logging.logger[self]
    end

    # Payload to index documents using the `_bulk` endpoint
    #
    # The format is as follows:
    #
    #   {"index": "mainstream", "type": "edition", "_id": "/bank-holidays"}
    #   { <document source> }
    #   {"index": "mainstream", "type": "edition", "_id": "/something-else"}
    #   { <document source> }
    #
    # See <http://www.elasticsearch.org/guide/reference/api/bulk/>
    def bulk_payload(document_hashes)
      index_items = document_hashes.map do |doc_hash|
        [index_action(doc_hash).to_json, doc_hash.to_json]
      end

      # Make sure the payload ends with a newline character: elasticsearch
      # requires this.
      index_items.flatten.join("\n") + "\n"
    end

    def index_action(doc_hash)
      {"index" => {"_type" => doc_hash["_type"], "_id" => doc_hash["link"]}}
    end

    def result_promoter
      @result_promoter ||= ResultPromoter.new(@promoted_results)
    end

    # Generate a hash from a Document to pass to elasticsearch.
    #
    # This allows for result promotion on top of the Document's in-built
    # `elasticsearch_export` method.
    def hash_from_document(document)
      with_promotion(document.elasticsearch_export)
    end

    def with_promotion(document_hash)
      result_promoter.with_promotion(document_hash)
    end

    def queue
      IndexQueue.new(index_name)
    end
  end
end
