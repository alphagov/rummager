require 'csv'

module Indexer
  class MetadataTagger
    def self.initialise(metadata_file_path, facet_config_file_path)
      @metadata = {}
      @config = YAML.load_file(facet_config_file_path)

      CSV.foreach(metadata_file_path, converters: lambda { |v| v || "" }) do |row|
        base_path = row[0]

        metadata_for_path = create_metadata_for_row(row)

        metadata_for_path["appear_in_find_eu_exit_guidance_business_finder"] = "yes"

        @metadata[base_path] = metadata_for_path
      end
    end

    def self.facets_from_finder_config
      @config["details"]["facets"]
    end

    def self.amend_all_metadata
      @metadata.each do |base_path, metadata|
        item_in_search = SearchConfig.instance.content_index.get_document_by_link(base_path)
        if item_in_search
          index_to_update = item_in_search["real_index_name"]
          Indexer::AmendWorker.new.perform(index_to_update, base_path, metadata)
        end
      end
    end

    def self.metadata_for_base_path(base_path)
      @metadata[base_path].to_h
    end

    def self.create_metadata_for_row(row)
      metadata = {}
      facets_from_finder_config.each_with_index do |facet, index|
        row_index = index + 1
        metadata[facet["key"]] = row.fetch(row_index, "").split(",").map(&:strip)
      end
      metadata.reject do |_, value|
        value == []
      end
    end

    def self.all_nil_metadata_hash
      metadata = {}

      facets_from_finder_config.each do |facet|
        metadata[facet["key"]] = nil
      end

      metadata
    end

    def self.remove_all_metadata_for_base_paths(base_paths)
      base_paths = Array(base_paths)

      base_paths.each do |base_path|
        item_in_search = SearchConfig.instance.content_index.get_document_by_link(base_path)
        if item_in_search
          index_to_update = item_in_search["real_index_name"]
          metadata_for_path = all_nil_metadata_hash
          metadata_for_path["appear_in_find_eu_exit_guidance_business_finder"] = nil
          Indexer::AmendWorker.new.perform(index_to_update, base_path, metadata_for_path)
        end
      end
    end
  end
end
