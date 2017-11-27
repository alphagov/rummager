require 'spec_helper'

RSpec.describe 'BestBetsTest' do
  with_ab_variants do
    it "exact_best_bet" do
      commit_document(
        "mainstream_test",
        "link" => '/an-organic-result',
        "indexable_content" => 'I will turn up in searches for "a forced best bet"',
      )

      commit_document(
        "mainstream_test",
        "link" => '/the-link-that-should-surface',
        "indexable_content" => 'Empty.',
      )

      add_best_bet(
        query: 'a forced best bet',
        type: 'exact',
        link: '/the-link-that-should-surface',
        position: 1,
      )

      links = get_links "/search?q=a+forced+best+bet"

      expect(links).to eq(["/the-link-that-should-surface", "/an-organic-result"])
    end

    it "exact_worst_bet" do
      commit_document(
        "mainstream_test",
        "indexable_content" => 'I should not be shown.',
        "link" => '/we-never-show-this',
      )

      add_worst_bet(
        query: 'shown',
        type: 'exact',
        link: '/we-never-show-this',
        position: 1,
      )

      links = get_links "/search?q=shown"

      expect(links).not_to include("/we-never-show-this")
    end

    it "stemmed_best_bet" do
      commit_document(
        "mainstream_test",
        "link" => '/the-link-that-should-surface',
      )

      add_best_bet(
        query: 'best bet',
        type: 'stemmed',
        link: '/the-link-that-should-surface',
        position: 1,
      )

      links = get_links "/search?q=best+bet+and+such"

      expect(links).to eq(["/the-link-that-should-surface"])
    end

    it "stemmed_best_bet_variant" do
      commit_document(
        "mainstream_test",
        "link" => '/the-link-that-should-surface',
      )

      add_best_bet(
        query: 'best bet',
        type: 'stemmed',
        link: '/the-link-that-should-surface',
        position: 1,
      )

      # note that we're searching for "bests bet", not "best bet" here.
      links = get_links "/search?q=bests+bet"

      expect(links).to eq(["/the-link-that-should-surface"])
    end

    it "stemmed_best_bet_words_not_in_phrase_order" do
      commit_document(
        "mainstream_test",
        "link" => '/only-shown-for-exact-matches',
      )

      add_best_bet(
        query: 'best bet',
        type: 'stemmed',
        link: '/only-shown-for-exact-matches',
        position: 1,
      )

      # note that we're searching for "bet best", not "best bet" here.
      links = get_links "/search?q=bet+best"

      expect(links).not_to include("/only-shown-for-exact-matches")
    end
  end

private

  def get_links(path)
    get_with_variant(path)
    parsed_response["results"].map { |result| result["link"] }
  end

  def add_best_bet(args)
    payload = build_sample_bet_hash(
      query: args[:query],
      type: args[:type],
      best_bets: [args.slice(:link, :position)],
      worst_bets: [],
    )

    post "/metasearch_test/documents", payload.to_json
    commit_index("metasearch_test")
  end

  def add_worst_bet(args)
    payload = build_sample_bet_hash(
      query: args[:query],
      type: args[:type],
      best_bets: [],
      worst_bets: [args.slice(:link, :position)],
    )

    post "/metasearch_test/documents", payload.to_json
    commit_index("metasearch_test")
  end

  def build_sample_bet_hash(query:, type:, best_bets:, worst_bets:)
    {
      "#{type}_query" => query,
      details: JSON.generate(
        {
          best_bets: best_bets,
          worst_bets: worst_bets,
        }
      ),
      _type: "best_bet",
      _id: "#{query}-#{type}",
    }
  end
end
