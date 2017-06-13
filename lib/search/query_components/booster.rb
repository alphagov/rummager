require "yaml"

module QueryComponents
  class Booster < BaseComponent
    FORMAT_BOOST_CONFIG = YAML.load_file('config/query/format_boosting.yml')
    DEFAULT_BOOST = 1

    def wrap(core_query)
      {
        function_score: {
          boost_mode: :multiply,
          score_mode: :multiply,
          query: {
            bool: {
              should: [core_query]
            }
          },
          functions: boost_filters,
        }
      }
    end

  private

    def format_boost_b_variant?
      @search_params.ab_tests[:format_boosting] == 'B'
    end

    def boost_filters
      boosts = format_boosts + [time_boost, closed_org_boost, devolved_org_boost, historic_edition_boost]

      if format_boost_b_variant?
        boosts + [guidance_boost]
      else
        boosts
      end
    end

    def boosted_formats
      if format_boost_b_variant?
        FORMAT_BOOST_CONFIG["format_boosts"]
      else
        formats_boosted_by_index
      end
    end

    def formats_boosted_by_index
      government_index_config = FORMAT_BOOST_CONFIG["government_index"]
      government_index_boost = government_index_config["boost"]
      government_formats = government_index_config["formats"]

      individual_format_boosts = FORMAT_BOOST_CONFIG["format_boosts"]

      boosted_formats = (government_formats + individual_format_boosts.keys).uniq

      boosted_formats.each_with_object({}) do |format_name, boosts|
        format_index_boost = government_formats.include?(format_name) ? government_index_boost : DEFAULT_BOOST
        individual_format_boost = individual_format_boosts.fetch(format_name, DEFAULT_BOOST)

        boosts[format_name] = format_index_boost * individual_format_boost
      end
    end

    def format_boosts
      boosted_formats.map do |format, boost|
        {
          filter: { term: { format: format } },
          boost_factor: boost
        }
      end
    end

    def guidance_boost
      {
        filter: { term: { navigation_document_supertype: "guidance" } },
        boost_factor: 2.5
      }
    end

    # An implementation of http://wiki.apache.org/solr/FunctionQuery#recip
    # Curve for 2 months: http://www.wolframalpha.com/share/clip?f=d41d8cd98f00b204e9800998ecf8427e5qr62u0si
    #
    # Behaves as a freshness boost for newer documents with a public_timestamp and search_format_types announcement
    def time_boost
      {
        filter: { term: { search_format_types: "announcement" } },
        script_score: {
          script: "((0.05 / ((3.16*pow(10,-11)) * abs(now - doc['public_timestamp'].date.getMillis()) + 0.05)) + 0.12)",
          params: {
            now: time_in_millis_to_nearest_minute,
          },
        }
      }
    end

    def time_in_millis_to_nearest_minute
      (Time.now.to_i / 60) * 60000
    end

    def closed_org_boost
      {
        filter: { term: { organisation_state: "closed" } },
        boost_factor: 0.2,
      }
    end

    def devolved_org_boost
      {
        filter: { term: { organisation_state: "devolved" } },
        boost_factor: 0.3,
      }
    end

    def historic_edition_boost
      {
        filter: { term: { is_historic: true } },
        boost_factor: 0.5,
      }
    end
  end
end
