worker: bundle exec sidekiq -C ./config/sidekiq.yml
publishing-queue-listener: bundle exec rake message_queue:listen_to_publishing_queue
govuk-index-queue-listener: bundle exec rake message_queue:insert_data_into_govuk
govuk-index-queue-reindex-listener: bundle exec rake message_queue:listen_to_reindexing_messages
