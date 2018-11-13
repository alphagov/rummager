module Search
  Registries = Struct.new(:search_server, :search_config) do
    def [](name)
      as_hash[name]
    end

    def as_hash
      @registries ||= {
        organisations: organisations,
        organisation_content_ids: organisations,
        specialist_sectors: specialist_sectors,
        topic_content_ids: specialist_sectors,

        # Whitehall has a thing called `topic`, which is being renamed to "policy
        # area", because there already are seven things called "topic". Until
        # Whitehall publishes the policy areas with format "policy_area" rather
        # than "topic", we will expand `policy_areas` with data from documents
        # with format `topic`.
        policy_areas: registry_for_document_format('topic'),
        document_series: registry_for_document_format('document_series'),
        document_collections: registry_for_document_format('document_collection'),
        world_locations: world_locations,
        people: registry_for_document_format('person'),
      }
    end

  private

    def organisations
      BaseRegistry.new(
        index,
        field_definitions,
        "organisation",
        %w{
          slug content_id
          link title acronym
          organisation_type
          organisation_closed_state
          organisation_state
          logo_formatted_title
          organisation_brand
          organisation_crest
          logo_url
          closed_at public_timestamp
          analytics_identifier
          child_organisations
          parent_organisations
          superseded_organisations
          superseding_organisations
        }
      )
    end

    def world_locations
      @world_locations ||= WorldLocationsRegistry.new
    end

    def specialist_sectors
      BaseRegistry.new(
        search_server.index_for_search([search_config.govuk_index_name]),
        field_definitions,
        "specialist_sector"
      )
    end

    def registry_for_document_format(format)
      BaseRegistry.new(index, field_definitions, format)
    end

    def index
      search_server.index_for_search([search_config.registry_index])
    end

    def field_definitions
      @field_definitions ||= search_server.schema.field_definitions
    end
  end
end
