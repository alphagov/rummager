require "search/result_set"
require_relative "result_presenter"
require_relative "facet_result_presenter"
require_relative "spell_check_presenter"

module Search
  # Presents a combined set of results for a GOV.UK site search
  class ResultSetPresenter
    attr_reader :es_response, :search_params

    # `registries` should be a map from registry names to registries,
    # which gets passed to the ResultSetPresenter class. For example:
    #
    #     { organisations: OrganisationRegistry.new(...) }
    #
    # `facet_examples` is {field_name => {facet_value => {total: count, examples: [{field: value}, ...]}}}
    # ie: a hash keyed by field name, containing hashes keyed by facet value with
    # values containing example information for the value.
    def initialize(search_params:,
                   es_response:,
                   registries: {},
                   facet_examples: {},
                   schema: nil,
                   query_payload: {})

      @es_response = es_response
      @facets = es_response["facets"]
      @search_params = search_params
      @registries = registries
      @facet_examples = facet_examples
      @schema = schema
      @query_payload = query_payload
    end

    def present
      response = {
        results: presented_results,
        total: es_response["hits"]["total"],
        start: search_params.start,
        facets: presented_facets,
        suggested_queries: suggested_queries
      }

      if search_params.show_query?
        response['elasticsearch_query'] = @query_payload
      end

      response
    end

  private

    def suggested_queries
      SpellCheckPresenter.new(es_response).present
    end

    def presented_results
      es_response["hits"]["hits"].map do |raw_result|
        results_hash = raw_result.to_hash
        results_hash['fields'] ||= results_hash.delete('_source')

        ResultPresenter.new(
          results_hash,
          @registries,
          @schema,
          search_params
        ).present
      end
    end

    def presented_facets
      FacetResultPresenter.new(@facets, @facet_examples, @search_params, @registries).presented_facets
    end
  end
end
