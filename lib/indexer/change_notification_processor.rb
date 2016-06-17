require 'index_finder'

# ChangeNotificationProcessor
#
# This is called by the message queue processor and is responsible
# for acting on the incoming payload. It checks if the updated document in the
# payload needs to be updated, looks up the document in elasticsearch and triggers
# a "re-index", which means that the document will go through the DocumentPreparer
# process and will look up the tags for the document again.
module Indexer
  module ChangeNotificationProcessor
    # Gets called with a content-item from the publishing-api message queue.
    def self.trigger(content_item)
      document = find_document(content_item)
      return :rejected unless document
      index_name = document['real_index_name']
      document_id = document['_id']
      updates = {}
      Indexer::AmendWorker.perform_async(index_name, document_id, updates)
      :accepted
    end

    def self.find_document(content_item)
      # Note that in the future the publishing-api may allow items without
      # `base_path`. When that starts we should bail out here instead of
      # crashing.
      document_base_path = content_item.fetch("base_path")
      index = IndexFinder.content_index
      index.get_document_by_link(document_base_path)
    end
  end
end
