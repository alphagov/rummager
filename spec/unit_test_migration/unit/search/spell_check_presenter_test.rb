require "test_helper"
require "search/presenters/spell_check_presenter"

class Search::SpellCheckPresenterTest < ShouldaUnitTestCase
  context "#present" do
    should "parse the elasticsearch response and return suggestions" do
      es_response = {
        "suggest" => {
          "spelling_suggestions" => [{
            "text" => "some query",
            "options" => [{
              "text" => "the first suggestion",
              "score" => 0.17877324
            }, {
              "text" => "the second suggestion",
              "score" => 0.14231323
            }]
          }]
        }
      }

      presenter = Search::SpellCheckPresenter.new(es_response)

      assert_equal presenter.present, ["the first suggestion", "the second suggestion"]
    end
  end
end
