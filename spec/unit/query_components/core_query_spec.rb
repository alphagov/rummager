require 'spec_helper'

RSpec.describe QueryComponents::CoreQuery do
  context "the search query with the B variant synonym analysis" do
    it "uses the new synonyms field" do
      builder = described_class.new(search_query_params(ab_tests: { synonyms: 'B' }))

      query = builder.minimum_should_match("all_searchable_text")

      expect(query.to_s).to match(/all_searchable_text\.synonym/)
      expect(query.to_s).not_to match(/query_with_old_synonyms/)
    end
  end

  context "the search query" do
    it "uses the query_with_old_synonyms analyzer" do
      builder = described_class.new(search_query_params)

      query = builder.minimum_should_match("_all")

      expect(query.to_s).to match(/query_with_old_synonyms/)
    end

    it "down-weight results which match fewer words in the search term" do
      builder = described_class.new(search_query_params)

      query = builder.minimum_should_match("_all")
      expect(query.to_s).to match(/"2<2 3<3 7<50%"/)
    end
  end

  context "the search query with synonyms disabled" do
    it "uses the default analyzer" do
      builder = described_class.new(search_query_params(debug: { disable_synonyms: true }))

      query = builder.minimum_should_match("_all")

      expect(query.to_s).to match(/default/)
      expect(query.to_s).not_to match(/query_with_old_synonyms/)
    end
  end
end
