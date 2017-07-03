require "test_helper"
require 'indexer/compare_enumerator'

class CompareEnumeratorTest < MiniTest::Unit::TestCase
  def test_when_matching_keys_exist
    data_left = { '_root_id' => 'abc', '_root_type' => 'stuff', 'custom' => 'data_left' }
    data_right = { '_root_id' => 'abc', '_root_type' => 'stuff', 'custom' => 'data_right' }

    stub_scroll_enumerator(left_request: [data_left], right_request: [data_right])

    results = Indexer::CompareEnumerator.new('index_a', 'index_b').map { |a| a }
    assert_equal results, [[data_left, data_right]]
  end

  def test_when_key_only_exists_in_left_index
    data = { '_root_id' => 'abc', '_root_type' => 'stuff', 'custom' => 'data_left' }

    stub_scroll_enumerator(left_request: [data], right_request: [])

    results = Indexer::CompareEnumerator.new('index_a', 'index_b').map { |a| a }
    assert_equal results, [[data, Indexer::CompareEnumerator::NO_VALUE]]
  end


  def test_when_key_only_exists_in_right_index
    data = { '_root_id' => 'abc', '_root_type' => 'stuff', 'custom' => 'data_right' }

    stub_scroll_enumerator(left_request: [], right_request: [data])

    results = Indexer::CompareEnumerator.new('index_a', 'index_b').map { |a| a }
    assert_equal results, [[Indexer::CompareEnumerator::NO_VALUE, data]]
  end

  def test_with_matching_ids_but_different_types
    data_left = { '_root_id' => 'abc', '_root_type' => 'stuff', 'custom' => 'data_left' }
    data_right = { '_root_id' => 'abc', '_root_type' => 'other_stuff', 'custom' => 'data_right' }

    stub_scroll_enumerator(left_request: [data_left], right_request: [data_right])

    results = Indexer::CompareEnumerator.new('index_a', 'index_b').map { |a| a }
    assert_equal results, [
      [Indexer::CompareEnumerator::NO_VALUE, data_right],
      [data_left, Indexer::CompareEnumerator::NO_VALUE],
    ]
  end

  def test_with_different_ids
    data_left = { '_root_id' => 'abc', '_root_type' => 'stuff', 'custom' => 'data_left' }
    data_right = { '_root_id' => 'def', '_root_type' => 'stuff', 'custom' => 'data_right' }

    stub_scroll_enumerator(left_request: [data_left], right_request: [data_right])

    results = Indexer::CompareEnumerator.new('index_a', 'index_b').map { |a| a }
    assert_equal results, [
      [data_left, Indexer::CompareEnumerator::NO_VALUE],
      [Indexer::CompareEnumerator::NO_VALUE, data_right],
    ]
  end


  def test_scroll_enumerator_mappings
    data = { '_id' => 'abc', '_type' => 'stuff', '_source' => { 'custom' => 'data' } }
    stub_client_for_scroll_enumerator(return_values: [[data], []])

    enum = Indexer::CompareEnumerator.new('index_a', 'index_b').get_enum('index_name')

    assert_equal enum.map { |a| a }, [
      { '_root_id' => 'abc', '_root_type' => 'stuff', 'custom' => 'data' }
    ]
  end

  def test_scroll_enumerator_mappings_when_filter_is_passed_in
    data = { '_id' => 'abc', '_type' => 'stuff', '_source' => { 'custom' => 'data' } }
    search_body = { query: 'custom_filter', sort: 'by_stuff' }

    stub_client_for_scroll_enumerator(return_values: [[data], []], search_body: search_body)

    enum = Indexer::CompareEnumerator.new('index_a', 'index_b').get_enum('index_name', search_body)

    assert_equal enum.map { |a| a }, [
      { '_root_id' => 'abc', '_root_type' => 'stuff', 'custom' => 'data' }
    ]
  end

  def test_scroll_enumerator_mappings_wthout_sorting
    data = { '_id' => 'abc', '_type' => 'stuff', '_source' => { 'custom' => 'data' } }
    search_body = { query: 'custom_filter' }

    stub_client_for_scroll_enumerator(return_values: [[data], []], search_body: search_body.merge(sort: Indexer::CompareEnumerator::DEFAULT_SORT))

    enum = Indexer::CompareEnumerator.new('index_a', 'index_b').get_enum('index_name', search_body)

    assert_equal enum.map { |a| a }, [
      { '_root_id' => 'abc', '_root_type' => 'stuff', 'custom' => 'data' }
    ]
  end

private

  def stub_scroll_enumerator(left_request:, right_request:)
    ScrollEnumerator.stubs(:new).returns(
      left_request.to_enum,
      right_request.to_enum,
    )
  end

  def stub_client_for_scroll_enumerator(return_values:, search_body: nil, search_type: "query_then_fetch")
    client = stub(:client)
    Services.stubs(:elasticsearch).returns(client)

    client.expects(:search).with(
      has_entries(
        index: 'index_name',
        search_type: search_type,
        body: search_body || {
          query: Indexer::CompareEnumerator::DEFAULT_QUERY,
          sort: Indexer::CompareEnumerator::DEFAULT_SORT,
        }
      )
    ).returns(
      { '_scroll_id' => 'scroll_ID_0', 'hits' => { 'total' => 1 }}
    )


    return_values.each_with_index do |return_value, i|
      client.expects(:scroll).with(
        scroll_id: "scroll_ID_#{i}", scroll: "1m"
      ).returns(
        { '_scroll_id' => "scroll_ID_#{i+1}", 'hits' => { 'hits' => return_value } }
      )
    end
  end
end
