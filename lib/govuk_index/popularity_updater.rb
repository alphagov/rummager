module GovukIndex
  class PopularityUpdater < Updater
    def self.update(index_name, process_all: false)
      new(
        source_index: index_name,
        destination_index: index_name,
        process_all: process_all,
      ).run

      worker.wait_until_processed
    end

    def self.worker
      PopularityWorker
    end

    def initialize(source_index:, destination_index:, process_all: false)
      @process_all = process_all

      super(
        source_index: source_index,
        destination_index: destination_index,
      )
    end

  private

    def search_body
      return { query: { match_all: {} } } if @process_all

      # only sync migrated formats as the rest will be updated via the sync job.
      {
        query: {
          terms: {
            format: MigratedFormats.indexable_formats.keys
          }
        }
      }
    end
  end
end
