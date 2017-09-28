require 'spec_helper'

RSpec.describe 'GovukIndex::PublishingEventProcessorTest', tags: ['integration'] do
  allow_elasticsearch_connection

  before do
    bunny_mock = BunnyMock.new
    @channel = bunny_mock.start.channel

    consumer = GovukMessageQueueConsumer::Consumer.new(
      queue_name: "bigwig.test",
      processor: GovukIndex::PublishingEventProcessor.new,
      rabbitmq_connection: bunny_mock
    )

    @queue = @channel.queue("bigwig.test")
    consumer.run
  end

  it "should_save_new_document_to_elasticsearch" do
    GovukIndex::MigratedFormats.stub(:indexable?).and_return(true)
    random_example = generate_random_example(
      payload: { document_type: "help_page", payload_version: 123 },
      regenerate_if: ->(example) { example["publishing_app"] == "smartanswers" }
    )

    @queue.publish(random_example.to_json, content_type: "application/json")
    commit_index 'govuk_test'

    document = fetch_document_from_rummager(id: random_example["base_path"], index: "govuk_test")

    assert_equal random_example["base_path"], document["_source"]["link"]
    assert_equal random_example["base_path"], document["_id"]
    assert_equal "edition", document["_type"]

    assert_equal 0, @queue.message_count
    assert_equal 1, @channel.acknowledged_state[:acked].count
  end

  it "not_indexing_when_publishing_app_is_smart_answers" do
    GovukIndex::MigratedFormats.stub(:indexable?).and_return(true)
    random_example = generate_random_example(
      payload: { document_type: "transaction", payload_version: 123, publishing_app: "smartanswers" },
    )

    @queue.publish(random_example.to_json, content_type: "application/json")
    commit_index 'govuk_test'

    assert_raises(Elasticsearch::Transport::Transport::Errors::NotFound) do
      fetch_document_from_rummager(id: random_example["base_path"], index: "govuk_test", type: 'edition')
    end
  end

  it "should_include_popularity_when_available" do
    GovukIndex::MigratedFormats.stub(:indexable?).and_return(true)
    random_example = generate_random_example(
      payload: { document_type: "help_page", payload_version: 123 },
      regenerate_if: ->(example) { example["publishing_app"] == "smartanswers" }
    )

    document_count = 4
    document_rank = 2
    insert_document("page-traffic_test", { rank_14: document_rank, path_components: [random_example["base_path"]] }, id: random_example["base_path"], type: "page-traffic")
    setup_page_traffic_data(document_count: document_count)

    popularity = 1.0 / ([document_count, document_rank].min + SearchConfig.instance.popularity_rank_offset)

    @queue.publish(random_example.to_json, content_type: "application/json")
    commit_index 'govuk_test'

    document = fetch_document_from_rummager(id: random_example["base_path"], index: "govuk_test")

    assert_equal popularity, document["_source"]["popularity"]
  end

  it "should_discard_message_when_invalid" do
    invalid_payload = {
      "title" => "Pitts S-2B, G-SKYD, 21 June 1996",
      "document_type" => "help_page",
    }

    expect(GovukError).to receive(:notify)
    @queue.publish(invalid_payload.to_json, extra: { content_type: "application/json" })

    assert_equal 0, @queue.message_count
  end

  it "should_discard_message_when_withdrawn_and_invalid" do
    invalid_payload = {
      "title" => "Pitts S-2B, G-SKYD, 21 June 1996",
      "document_type" => "gone",
    }

    expect(GovukError).to receive(:notify)
    @queue.publish(invalid_payload.to_json, extra: { content_type: "application/json" })

    assert_equal 0, @queue.message_count
  end

  def client
    @client ||= Services::elasticsearch(hosts: SearchConfig.instance.base_uri)
  end
end
