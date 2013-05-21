require "test_helper"
require "document"

class DocumentTest < MiniTest::Unit::TestCase
  include Fixtures::DefaultMappings

  def setup
    @mappings = default_mappings
  end

  def test_should_turn_hash_into_document
    hash = {
      "title" => "TITLE",
      "description" => "DESCRIPTION",
      "format" => "answer",
      "section" => "Life in the UK",
      "subsection" => 'Queuing',
      "subsubsection" => 'Barging to the front',
      "link" => "/an-example-answer",
      "indexable_content" => "HERE IS SOME CONTENT",
    }

    document = Document.from_hash(hash, @mappings)

    assert_equal "TITLE", document.title
    assert_equal "DESCRIPTION", document.description
    assert_equal "answer", document.format
    assert_equal "Life in the UK", document.section
    assert_equal "Queuing", document.subsection
    assert_equal "Barging to the front", document.subsubsection
    assert_equal "/an-example-answer", document.link
    assert_equal "HERE IS SOME CONTENT", document.indexable_content
  end

  def test_should_turn_hash_with_non_standard_field_into_document
    hash = {
      "title" => "TITLE",
      "description" => "DESCRIPTION",
      "format" => "guide",
      "link" => "/an-example-guide",
      "topics" => [1,2]
    }

    mappings = default_mappings
    mappings['edition']['properties'].merge!({"topics" => { "type" => "string", "index" => "not_analyzed" }})
    document = Document.from_hash(hash, mappings)

    assert_equal [1,2], document.to_hash["topics"]
    assert_equal [1,2], document.topics
    assert_equal [1,2], document.elasticsearch_export["topics"]
  end

  def test_should_ignore_fields_not_in_mappings
    hash = {
      "title" => "TITLE",
      "description" => "DESCRIPTION",
      "format" => "guide",
      "link" => "/an-example-guide",
      "some_other_field" => "test"
    }

    document = Document.from_hash(hash, @mappings)

    refute_includes document.to_hash.keys, "some_other_field"
    refute document.respond_to?("some_other_field")
  end

  def test_should_recognise_symbol_keys_in_hash
    hash = {
      :title => "TITLE",
      :description => "DESCRIPTION",
      :format => "guide",
      :link => "/an-example-guide",
      :indexable_content => "HERE IS SOME CONTENT"
    }

    document = Document.from_hash(hash, @mappings)

    assert_equal "TITLE", document.title
  end

  def test_should_round_trip_document_from_hash_and_back_into_hash
    hash = {
      "title" => "TITLE",
      "description" => "DESCRIPTION",
      "format" => "guide",
      "link" => "/an-example-guide",
      "indexable_content" => "HERE IS SOME CONTENT"
    }

    document = Document.from_hash(hash, @mappings)
    assert_equal hash, document.to_hash
  end

  def test_should_skip_missing_fields_in_to_hash
    hash = {
      "title" => "TITLE",
      "description" => "DESCRIPTION",
      "format" => "guide",
      "link" => "/an-example-guide"
    }

    document = Document.from_hash(hash, @mappings)
    assert_equal hash.keys.sort, document.to_hash.keys.sort
  end

  def test_should_skip_missing_fields_in_elasticsearch_export
    hash = {
        "_type" => "edition",
        "title" => "TITLE",
        "description" => "DESCRIPTION",
        "format" => "guide",
        "link" => "/an-example-guide",
    }
    document = Document.from_hash(hash, @mappings)

    assert_equal hash.keys.sort, document.elasticsearch_export.keys.sort
  end
end
