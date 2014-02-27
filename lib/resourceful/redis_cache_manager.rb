require 'resourceful/cache_manager'
require 'redis'
require 'time'

module Resourceful
  # Stores cache entries in Redis. Similarly to the
  # InMemoryCacheManager there are no limits on storage, so this will eventually
  # eat up all your Memory unless you run Redis with maxmemory!
  class RedisCacheManager < AbstractCacheManager

    def initialize
      @redis = Redis.new
    end

    def lookup(request)
      response = cache_entries_for(request)[request]
      response.authoritative = false if response
      response
    end

    def store(request, response)
      return unless response.cacheable?

      entries = cache_entries_for(request)
      entries[request] = response

      @redis.set(uri_hash(request.uri), Marshal.dump(entries))
    end

    def invalidate(uri)
      @redis.delete(uri_hash(uri))
    end

    private
    def cache_entries_for(request)
      if entries = @redis.get(uri_hash(request.uri))
        Marshal.load(entries)
      else
        Resourceful::CacheEntryCollection.new
      end
    end
  end
end
