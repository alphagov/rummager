require 'spec_helper'

RSpec.describe 'GovukIndex::UnpublishingMessageProcessing', tags: ['integration'] do
  allow_elasticsearch_connection

  it "unpublish_message_will_remove_record_from_elasticsearch" do
    allow(GovukIndex::MigratedFormats).to receive(:migrated_formats).and_return(%w(answer))

    message = unpublishing_event_message(
      "gone",
      user_defined: {
        payload_version: 2,
        base_path: "/carrots",
        document_type: "gone"
      },
      excluded_fields: ['withdrawn_notice']
    )
    base_path = message.payload['base_path']

    commit_document('govuk_test', { 'link' => base_path }, id: base_path, type: 'answer')
    expect_document_is_in_rummager({ 'link' => base_path }, index: 'govuk_test', type: 'answer')

    processor = GovukIndex::PublishingEventProcessor.new

    processor.process(message)
    commit_index('govuk_test')

    expect {
      fetch_document_from_rummager(id: base_path, index: 'govuk_test', type: 'answer')
    }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
  end

  it "unpublish_withdrawn_messages_will_set_is_withdrawn_flag" do
    allow(GovukIndex::MigratedFormats).to receive(:migrated_formats).and_return(%w(help_page))

    message = unpublishing_event_message(
      "help_page",
      user_defined: {
        payload_version: 2,
        document_type: "help_page",
        withdrawn_notice: {
          "explanation" => "<div class=\"govspeak\"><p>test 2</p>\n</div>",
          "withdrawn_at" => "2017-08-03T14:02:18Z"
        }
      }
    )
    base_path = message.payload['base_path']
    type = 'edition'

    commit_document('govuk_test', { 'link' => base_path }, id: base_path, type: type)

    expect_document_is_in_rummager({ 'link' => base_path, 'is_withdrawn' => nil }, index: 'govuk_test', type: type)
    processor = GovukIndex::PublishingEventProcessor.new

    processor.process(message)
    commit_index('govuk_test')

    expect_document_is_in_rummager({ 'link' => base_path, 'is_withdrawn' => true }, index: 'govuk_test', type: type)
  end

  def unpublishing_event_message(schema_name, user_defined: {}, excluded_fields: [])
    payload = GovukSchemas::RandomExample
      .for_schema(notification_schema: schema_name)
      .customise_and_validate(user_defined, excluded_fields)
    stub_message_payload(payload, unpublishing: true)
  end
end
