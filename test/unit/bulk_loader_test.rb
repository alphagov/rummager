require "test_helper"
require "bulk_loader"
require "stringio"
require "logger"

class BulkLoaderTest < MiniTest::Unit::TestCase
  def test_can_break_iostream_into_batches_of_lines_of_specified_byte_size
    input = StringIO.new(%w{a b c d}.join("\n") + "\n")
    loader = BulkLoader.new(stub("search config"), stub("index name"))
    batches = []
    loader.send(:in_even_sized_batches, input, 4) do |batch|
      batches << batch
    end

    assert_equal [["a\n", "b\n"], ["c\n", "d\n"]], batches
  end

  def test_line_pairs_are_not_split_if_batch_size_too_small_to_fit_first_pair_of_lines
    input = StringIO.new(%w{a b c d}.join("\n") + "\n")
    loader = BulkLoader.new(stub("search config"), stub("index name"))
    batches = []
    loader.send(:in_even_sized_batches, input, 3) do |batch|
      batches << batch
    end

    assert_equal [["a\n", "b\n"], ["c\n", "d\n"]], batches
  end

  def test_line_pairs_are_not_split_if_batch_boundary_falls_in_second_pair_of_lines
    input = StringIO.new(%w{a b c d e f}.join("\n") + "\n")
    loader = BulkLoader.new(stub("search config"), stub("index name"))
    batches = []
    loader.send(:in_even_sized_batches, input, 5) do |batch|
      batches << batch
    end

    assert_equal [["a\n", "b\n", "c\n", "d\n"], ["e\n", "f\n"]], batches
  end
end
