require "test_helper"
require "search/query_builder"

describe QueryComponents::Highlight do
  describe '#payload' do
    it 'enables highlighting on title' do
      parameters = Search::QueryParameters.new(return_fields: %w[title_with_highlighting])

      payload = QueryComponents::Highlight.new(parameters).payload

      assert payload[:fields].keys.include?(:title)
    end

    it 'enables highlighting on description' do
      parameters = Search::QueryParameters.new(return_fields: %w[description_with_highlighting])

      payload = QueryComponents::Highlight.new(parameters).payload

      assert payload[:fields].keys.include?(:description)
    end

    it 'does not enable highlighting when not requested' do
      parameters = Search::QueryParameters.new(return_fields: %w[title])

      payload = QueryComponents::Highlight.new(parameters).payload

      assert payload.nil?
    end
  end
end
