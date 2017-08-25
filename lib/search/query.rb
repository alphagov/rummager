# Performs a search across all indices used for the GOV.UK site search
module Search
  class Query
    class Error < StandardError; end
    class NumberOutOfRange < Error; end
    class QueryTooLong < Error; end

    attr_reader :index, :registries, :spelling_index, :suggestion_blacklist

    def initialize(registries:, content_index:, metasearch_index:, spelling_index:)
      @index = content_index
      @registries = registries
      @metasearch_index = metasearch_index
      @spelling_index = spelling_index
      @suggestion_blacklist = SuggestionBlacklist.new(registries)
    end

    # Search and combine the indices and return a hash of ResultSet objects
    def run(search_params)
      builder = QueryBuilder.new(
        search_params: search_params,
        content_index_names: content_index_names,
        metasearch_index: metasearch_index
      )

      payload     = process_elasticsearch_errors { builder.payload }
      es_response = process_elasticsearch_errors { index.raw_search(payload) }

      example_fetcher = AggregateExampleFetcher.new(index, es_response, search_params, builder)
      aggregate_examples = example_fetcher.fetch

      # Augment the response with the suggest result from a separate query.
      if search_params.suggest_spelling?
        es_response['suggest'] = run_spell_checks(search_params)
      end

      ResultSetPresenter.new(
        search_params: search_params,
        es_response: es_response,
        registries: registries,
        aggregate_examples: aggregate_examples,
        schema: index.schema,
        query_payload: payload
      ).present
    end

    # Elasticsearch tries to find spelling suggestions for words that don't occur in
    # our content, as they are probably mispelled. However, currently it is
    # returning suggestions for words that do not occur in *every* index. Because
    # some indexes contain very few words, Elasticsearch returns too many spelling
    # suggestions for common terms. For example, using the suggester on all indices
    # will yield a suggestion for "PAYE", because it's mentioned only in the
    # `government` index, and not in other indexes.
    #
    # This issue is mentioned in
    # https://github.com/elastic/elasticsearch/issues/7472.
    #
    # Our solution is to run a separate query to fetch the suggestions, only using
    # the indices we want.
    def run_spell_checks(search_params)
      return unless suggestion_blacklist.should_correct?(search_params.query)

      query = {
        size: 0,
        suggest: QueryComponents::Suggest.new(search_params).payload
      }

      response = spelling_index.raw_search(query)

      response['suggest']
    end

  private

    attr_reader :metasearch_index

    def content_index_names
      # index is a IndexForSearch object, which combines all the content indexes
      index.index_names
    end

    def fetch_spell_checks(search_params)
      SpellCheckFetcher.new(search_params, registries).es_response
    end

    def process_elasticsearch_errors
      yield
    rescue Elasticsearch::Transport::Transport::Errors::InternalServerError => e
      case e.message
      when /Numeric value \(([0-9]*)\) out of range of/
        raise(NumberOutOfRange, "Integer value of #{$1} exceeds maximum allowed")
      when /maxClauseCount is set to/
        raise(QueryTooLong, 'Query must be less than 1024 words')
      else
        raise
      end
    end
  end
end
