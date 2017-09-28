require 'spec_helper'

RSpec.describe SearchIndices::IndexGroup do
  ELASTICSEARCH_OK = {
    status: 200,
    body: { "ok" => true, "acknowledged" => true }.to_json
  }.freeze

  before do
    @schema = SearchConfig.instance.search_server.schema
    @server = SearchIndices::SearchServer.new(
      SearchConfig.instance.base_uri,
      @schema,
      %w(mainstream custom),
      'govuk',
      ["mainstream"],
      SearchConfig.new
    )
  end

  it "create_index" do
    expected_body = {
      "settings" => @schema.elasticsearch_settings("mainstream"),
      "mappings" => @schema.elasticsearch_mappings("mainstream"),
    }.to_json
    stub = stub_request(:put, %r(#{SearchConfig.instance.base_uri}/mainstream-.*))
      .with(body: expected_body)
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: '{"ok": true, "acknowledged": true}'
      )
    index = @server.index_group("mainstream").create_index

    assert_requested(stub)
    assert index.is_a? SearchIndices::Index
    assert_match(/^mainstream-/, index.index_name)
  end

  it "switch_index_with_no_existing_alias" do
    new_index = double("New index", index_name: "test-new")
    get_stub = stub_request(:get, "#{SearchConfig.instance.base_uri}/_aliases")
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          "test-new" => { "aliases" => {} }
        }.to_json
      )
    expected_body = {
      "actions" => [
        { "add" => { "index" => "test-new", "alias" => "test" } }
      ]
    }.to_json
    post_stub = stub_request(:post, "#{SearchConfig.instance.base_uri}/_aliases")
      .with(
        body: expected_body,
        headers: { 'Content-Type' => 'application/json' }
      )
      .to_return(ELASTICSEARCH_OK)

    @server.index_group("test").switch_to(new_index)

    assert_requested(get_stub)
    assert_requested(post_stub)
  end

  it "switch_index_with_existing_alias" do
    new_index = double("New index", index_name: "test-new")
    get_stub = stub_request(:get, "#{SearchConfig.instance.base_uri}/_aliases")
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          "test-old" => { "aliases" => { "test" => {} } },
          "test-new" => { "aliases" => {} }
        }.to_json
      )

    expected_body = {
      "actions" => [
        { "remove" => { "index" => "test-old", "alias" => "test" } },
        { "add" => { "index" => "test-new", "alias" => "test" } }
      ]
    }.to_json
    post_stub = stub_request(:post, "#{SearchConfig.instance.base_uri}/_aliases")
      .with(body: expected_body)
      .to_return(ELASTICSEARCH_OK)

    @server.index_group("test").switch_to(new_index)

    assert_requested(get_stub)
    assert_requested(post_stub)
  end

  it "switch_index_with_multiple_existing_aliases" do
    # Not expecting the system to get into this state, but it should cope
    new_index = double("New index", index_name: "test-new")
    get_stub = stub_request(:get, "#{SearchConfig.instance.base_uri}/_aliases")
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          "test-old" => { "aliases" => { "test" => {} } },
          "test-old2" => { "aliases" => { "test" => {} } },
          "test-new" => { "aliases" => {} }
        }.to_json
      )

    expected_body = {
      "actions" => [
        { "remove" => { "index" => "test-old", "alias" => "test" } },
        { "remove" => { "index" => "test-old2", "alias" => "test" } },
        { "add" => { "index" => "test-new", "alias" => "test" } }
      ]
    }.to_json
    post_stub = stub_request(:post, "#{SearchConfig.instance.base_uri}/_aliases")
      .with(body: expected_body)
      .to_return(ELASTICSEARCH_OK)

    @server.index_group("test").switch_to(new_index)

    assert_requested(get_stub)
    assert_requested(post_stub)
  end

  it "switch_index_with_existing_real_index" do
    new_index = double("New index", index_name: "test-new")
    stub_request(:get, "#{SearchConfig.instance.base_uri}/_aliases")
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          "test" => { "aliases" => {} }
        }.to_json
      )

    assert_raises RuntimeError do
      @server.index_group("test").switch_to(new_index)
    end
  end

  it "index_names_with_no_indices" do
    stub_request(:get, %r{#{SearchConfig.instance.base_uri}/test\*\?.*})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {}.to_json
      )

    assert_equal [], @server.index_group("test").index_names
  end

  it "index_names_with_index" do
    index_name = "test-2012-03-01t12:00:00z-12345678-1234-1234-1234-123456789012"
    stub_request(:get, %r{#{SearchConfig.instance.base_uri}/test\*\?.*})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          index_name => { "aliases" => { "test" => {} } }
        }.to_json
      )

    assert_equal [index_name], @server.index_group("test").index_names
  end

  it "index_names_with_other_groups" do
    this_name = "test-2012-03-01t12:00:00z-12345678-1234-1234-1234-123456789012"
    other_name = "fish-2012-03-01t12:00:00z-87654321-4321-4321-4321-210987654321"

    stub_request(:get, %r{#{SearchConfig.instance.base_uri}/test\*\?.*})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          this_name => { "aliases" => {} },
          other_name => { "aliases" => {} }
        }.to_json
      )

    assert_equal [this_name], @server.index_group("test").index_names
  end

  it "clean_with_no_indices" do
    stub_request(:get, %r{#{SearchConfig.instance.base_uri}/test\*\?.*})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {}.to_json
      )

    @server.index_group("test").clean
  end

  it "clean_with_dead_index" do
    index_name = "test-2012-03-01t12:00:00z-12345678-1234-1234-1234-123456789012"
    stub_request(:get, %r{#{SearchConfig.instance.base_uri}/test\*\?.*})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          index_name => { "aliases" => {} }
        }.to_json
      )

    delete_stub = stub_request(:delete, "#{SearchConfig.instance.base_uri}/#{index_name}")
      .to_return(ELASTICSEARCH_OK)

    @server.index_group("test").clean

    assert_requested delete_stub
  end

  it "clean_with_live_index" do
    index_name = "test-2012-03-01t12:00:00z-12345678-1234-1234-1234-123456789012"
    stub_request(:get, %r{#{SearchConfig.instance.base_uri}/test\*\?.*})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          index_name => { "aliases" => { "test" => {} } }
        }.to_json
      )

    @server.index_group("test").clean
  end

  it "clean_with_multiple_indices" do
    index_names = [
      "test-2012-03-01t12:00:00z-12345678-1234-1234-1234-123456789012",
      "test-2012-03-01t12:00:00z-abcdefab-abcd-abcd-abcd-abcdefabcdef"
    ]
    stub_request(:get, %r{#{SearchConfig.instance.base_uri}/test\*\?.*})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          index_names[0] => { "aliases" => {} },
          index_names[1] => { "aliases" => {} }
        }.to_json
      )

    delete_stubs = index_names.map { |index_name|
      stub_request(:delete, "#{SearchConfig.instance.base_uri}/#{index_name}")
        .to_return(ELASTICSEARCH_OK)
    }

    @server.index_group("test").clean

    delete_stubs.each do |delete_stub| assert_requested delete_stub end
  end

  it "clean_with_live_and_dead_indices" do
    live_name = "test-2012-03-01t12:00:00z-12345678-1234-1234-1234-123456789012"
    dead_name = "test-2012-03-01t12:00:00z-87654321-4321-4321-4321-210987654321"

    stub_request(:get, %r{#{SearchConfig.instance.base_uri}/test\*\?.*})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          live_name => { "aliases" => { "test" => {} } },
          dead_name => { "aliases" => {} }
        }.to_json
      )

    delete_stub = stub_request(:delete, "#{SearchConfig.instance.base_uri}/#{dead_name}")
      .to_return(ELASTICSEARCH_OK)

    @server.index_group("test").clean

    assert_requested delete_stub
  end

  it "clean_with_other_alias" do
    # If there's an alias we don't know about, that should save the index
    index_name = "test-2012-03-01t12:00:00z-12345678-1234-1234-1234-123456789012"
    stub_request(:get, %r{#{SearchConfig.instance.base_uri}/test\*\?.*})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          index_name => { "aliases" => { "something_else" => {} } }
        }.to_json
      )

    @server.index_group("test").clean
  end

  it "clean_with_other_groups" do
    # Check we don't go around deleting index from other groups
    this_name = "test-2012-03-01t12:00:00z-12345678-1234-1234-1234-123456789012"
    other_name = "fish-2012-03-01t12:00:00z-87654321-4321-4321-4321-210987654321"

    stub_request(:get, %r{#{SearchConfig.instance.base_uri}/test\*\?.*})
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          this_name => { "aliases" => {} },
          other_name => { "aliases" => {} }
        }.to_json
      )

    delete_stub = stub_request(:delete, "#{SearchConfig.instance.base_uri}/#{this_name}")
      .to_return(ELASTICSEARCH_OK)

    @server.index_group("test").clean

    assert_requested delete_stub
  end
end
