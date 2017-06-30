require "test_helper"
require "search/query_builder"

class CoreQueryTest < ShouldaUnitTestCase
  context "search with debug disabling use of synonyms" do
    should "use the query_with_old_synonyms analyzer" do
      builder = QueryComponents::CoreQuery.new(search_query_params)

      query = builder.payload

      assert_match(/query_with_old_synonyms/, query.to_s)
    end

    should "not use the query_with_old_synonyms analyzer" do
      builder = QueryComponents::CoreQuery.new(search_query_params(debug: { disable_synonyms: true }))

      query = builder.payload

      refute_match(/query_with_old_synonyms/, query.to_s)
    end
  end

  context "the search query" do
    should "down-weight results which match fewer words in the search term" do
      builder = QueryComponents::CoreQuery.new(search_query_params)

      query = builder.payload
      refute_match(/"2<2 3<3 7<50%"/, query[:bool][:must].to_s)
      assert_match(/"2<2 3<3 7<50%"/, query[:bool][:should].to_s)
    end
  end
end
