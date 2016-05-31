# Hides some of the dirtyness in selecting/generating the correct index objects
class IndexFinder
  class << self
    def content_index
      search_config.search_server.index_for_search(search_config.content_index_names)
    end

    def by_name(index_name)
      search_server.index(index_name)
    end

    def search_config
      @search_config ||= Rummager.settings.search_config
    end

    def search_server
      @search_server ||= search_config.search_server
    end
  end
end
