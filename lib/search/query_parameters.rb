module Search
  # Value object that holds the parsed parameters for a search.
  class QueryParameters
    attr_accessor :query, :similar_to, :order, :start, :count, :return_fields,
                  :facets, :filters, :debug, :suggest, :is_quoted_phrase

    # starts and ends with quotes with no quotes in between, with or without
    # leading or trailing whitespace
    QUOTED_STRING_REGEX = /^\s*"[^"]+"\s*$/

    def initialize(params = {})
      params = { facets: [], filters: {}, debug: {}, return_fields: [] }.merge(params)
      params.each do |k, v|
        public_send("#{k}=", v)
      end
      determine_if_quoted_phrase
    end

    def quoted_search_phrase?
      @is_quoted_phrase
    end

    def field_requested?(name)
      return_fields.include?(name)
    end

    def disable_popularity?
      debug[:disable_popularity]
    end

    def disable_synonyms?
      debug[:disable_synonyms]
    end

    def enable_new_weighting?
      debug[:new_weighting]
    end

    def disable_best_bets?
      debug[:disable_best_bets]
    end

    def enable_id_codes?
      debug[:use_id_codes]
    end

    def show_query?
      debug[:show_query]
    end

    def suggest_spelling?
      query && suggest.include?('spelling')
    end

  private

    def determine_if_quoted_phrase
      if @query =~ QUOTED_STRING_REGEX
        @is_quoted_phrase = true
      else
        @is_quoted_phrase = false
      end
    end
  end
end
