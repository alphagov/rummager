require "test_helper"
require "search/presenters/highlighted_title"

class HighlightedTitleTest < MiniTest::Unit::TestCase
  def test_title_highlighted
    title = Search::HighlightedTitle.new({
      "fields" => { "title" => "A Title" },
      "highlight" => { "title" => ["A Highlighted Title"] }
    })

    assert_equal "A Highlighted Title", title.text
  end

  def test_fallback_title_is_escaped
    title = Search::HighlightedTitle.new({
      "fields" => { "title" => "A & Title" },
    })

    assert_equal "A &amp; Title", title.text
  end
end
