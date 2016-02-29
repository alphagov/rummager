require "uri"
require "elasticsearch/index_group"
require "elasticsearch/index_for_search"

module Elasticsearch
  class NoSuchIndex < ArgumentError; end

  class SearchServer
    attr_reader :schema

    def initialize(base_uri, schema, index_names, content_index_names,
                   search_config)
      @base_uri = URI.parse(base_uri)
      @schema = schema
      @index_names = index_names
      @content_index_names = content_index_names
      @search_config = search_config
    end

    def index_group(prefix)
      IndexGroup.new(
        @base_uri,
        prefix,
        @schema,
        @search_config
      )
    end

    def index(index_name)
      validate_index_name!(index_name)
      index_group(index_name).current
    end

    def index_for_search(names)
      names.each do |index_name|
        validate_index_name!(index_name)
      end
      IndexForSearch.new(@base_uri, names, @schema, @search_config)
    end

    def content_indices
      @content_index_names.map do |index_name|
        index(index_name)
      end
    end

    def snapshot_bucket
      Bucket.new(
          bucket_name: search_config.snapshot_bucket_name
      )
    end

  private

    def validate_index_name!(index_name)
      return if index_name_valid?(index_name)

      raise NoSuchIndex,
        "Index name #{index_name} is not specified in the elasticsearch settings."
    end

    def index_name_valid?(index_name)
      index_name.split(",").all? do |name|
        @index_names.include?(name)
      end
    end
  end
end
