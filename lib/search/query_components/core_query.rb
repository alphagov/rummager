module QueryComponents
  class CoreQuery < BaseComponent
    DEFAULT_QUERY_ANALYZER = "query_with_old_synonyms".freeze
    DEFAULT_QUERY_ANALYZER_WITHOUT_SYNONYMS = 'default'.freeze

    # TODO: The `score` here doesn't actually do anything.
    MATCH_FIELDS = {
      "title" => 5,
      "acronym" => 5, # Ensure that organisations rank brilliantly for their acronym
      "description" => 2,
      "indexable_content" => 1,
    }.freeze

    # The following specification generates the following values for minimum_should_match
    #
    # Number of | Minimum
    # optional  | should
    # clauses   | match
    # ----------+---------
    # 1         | 1
    # 2         | 2
    # 3         | 2
    # 4         | 3
    # 5         | 3
    # 6         | 3
    # 7         | 3
    # 8+        | 50%
    #
    # This table was worked out by using the comparison feature of
    # bin/search with various example queries of different lengths (3, 4, 5,
    # 7, 9 words) and inspecting the consequences on search results.
    #
    # Reference for the minimum_should_match syntax:
    # http://lucene.apache.org/solr/api-3_6_2/org/apache/solr/util/doc-files/min-should-match.html
    #
    # In summary, a clause of the form "N<M" means when there are MORE than
    # N clauses then M clauses should match. So, 2<2 means when there are
    # MORE than 2 clauses then 2 should match.
    MINIMUM_SHOULD_MATCH = "2<2 3<3 7<50%".freeze
    MINIMUM_SHOULD_MATCH_VARIANT_B = "2<2".freeze

    def payload
      if @search_params.quoted_search_phrase?
        payload_for_quoted_phrase
      else
        payload_for_unquoted_phrase
      end
    end

  private

    def payload_for_unquoted_phrase
      {
        bool: {
          must: must_conditions,
          should: should_conditions
        }
      }
    end

    def payload_for_quoted_phrase
      groups = [field_boosts_phrase]
      groups.map { |queries| dis_max_query(queries) }
    end

    def must_conditions
      if @search_params.enable_id_codes?
        [all_searchable_text_query]
      else
        [query_string_query]
      end
    end

    def should_conditions
      exact_field_boosts + [exact_match_boost, shingle_token_filter_boost]
    end

    def all_searchable_text_query
      # Return the highest weight obtained by searching for the text when
      # analyzed in different ways (with a small bonus if it matches in
      # multiple of these ways).
      queries = []

      queries << query_string_query
      queries << match_query("all_searchable_text.id_codes", search_term, minimum_should_match: "1")

      dis_max_query(queries, tie_breaker: 0.1)
    end

    def query_string_query
      {
        match: {
          _all: {
            query: escape(search_term),
            analyzer: query_analyzer,
            minimum_should_match: minimum_should_match,
          }
        }
      }
    end

    def minimum_should_match
      if @search_params.ab_tests[:search_match_length] == 'B'
        MINIMUM_SHOULD_MATCH_VARIANT_B
      else
        MINIMUM_SHOULD_MATCH
      end
    end

    def exact_field_boosts
      MATCH_FIELDS.map do |field_name, _|
        {
          match_phrase: {
            field_name => {
              query: escape(search_term),
              analyzer: query_analyzer,
            }
          }
        }
      end
    end

    def field_boosts_phrase
      # Return the highest weight found by looking for a phrase match in
      # individual fields
      MATCH_FIELDS.map { |field_name, boost|
        match_query("#{field_name}.no_stop", search_term, type: :phrase, boost: boost)
      }
    end

    def exact_match_boost
      {
        multi_match: {
          query: escape(search_term),
          operator: "and",
          fields: MATCH_FIELDS.keys,
          analyzer: query_analyzer
        }
      }
    end

    def shingle_token_filter_boost
      {
        multi_match: {
          query: escape(search_term),
          operator: "or",
          fields: MATCH_FIELDS.keys,
          analyzer: "shingled_query_analyzer"
        }
      }
    end

    def query_analyzer
      if search_params.disable_synonyms?
        DEFAULT_QUERY_ANALYZER_WITHOUT_SYNONYMS
      else
        DEFAULT_QUERY_ANALYZER
      end
    end

    def match_query(field_name, query, type: :boolean, boost: 1.0, minimum_should_match: MINIMUM_SHOULD_MATCH, operator: :or)
      {
        match: {
          field_name => {
            type: type,
            boost: boost,
            query: query,
            minimum_should_match: minimum_should_match,
            operator: operator,
          }
        }
      }
    end

    def dis_max_query(queries, tie_breaker: 0.0, boost: 1.0)
      # Calculates a score by running all the queries, and taking the maximum.
      # Adds in the scores for the other queries multiplied by `tie_breaker`.
      if queries.size == 1
        queries.first
      else
        {
          dis_max: {
            queries: queries,
            tie_breaker: tie_breaker,
            boost: boost,
          }
        }
      end
    end
  end
end
