require "timed_cache"

class TopicRegistry
  CACHE_LIFETIME = 12 * 3600  # 12 hours

  def initialize(index, clock = Time)
    @index = index
    @cache = TimedCache.new(CACHE_LIFETIME, clock) { fetch }
  end

  def [](slug)
    @cache.get.find { |o| o.link == "/government/topics/#{slug}" }
  end

private
  def fetch
    fields = %w(link title)
    @index.documents_by_format("topic", fields: fields).to_a
  end
end
