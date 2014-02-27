require "resourceful/cache_manager"

require 'memcache'

module Resourceful
  class MemcacheCacheManager < AbstractCacheManager

    # Create a new Memcached backed cache manager
    #
    # @param [*String] memcache_servers
    #   list of all Memcached servers this cache manager should use.
    def initialize(*memcache_servers)
      @memcache = MemCache.new(memcache_servers, :multithread => true)
    end

    # Finds a previously cached response to the provided request.  The
    # response returned may be stale.
    #
    # @param [Resourceful::Request] request
    #   The request for which we are looking for a response.
    #
    # @return [Resourceful::Response, nil]
    #   A (possibly stale) response for the request provided or nil if
    #   no matching response is found.
    def lookup(request)
      resp = cache_entries_for(request)[request]
      return if resp.nil?

      resp.authoritative = false

      resp
    end

    # Store a response in the cache.
    #
    # This method is smart enough to not store responses that cannot be
    # cached (Vary: * or Cache-Control: no-cache, private, ...)
    #
    # @param [Resourceful::Request] request
    #   The request used to obtain the response. This is needed so the
    #   values from the response's Vary header can be stored.
    # @param [Resourceful::Response] response
    #   The response to be stored.
    def store(request, response)
      return unless response.cacheable?

      entries = cache_entries_for(request)
      entries[request] = response

      @memcache[uri_hash(request.uri)] = Marshal.dump(entries)
    end

    # Invalidates a all cached entries for a uri.
    #
    # This is used, for example, to invalidate the cache for a resource
    # that gets POSTed to.
    #
    # @param [String] uri
    #   The uri of the resource to be invalidated
    def invalidate(uri)
      @memcache.delete(uri_hash(uri))
    end


    private

    ##
    # The memcache proxy.
    attr_reader :memcache

    def cache_entries_for(a_request)
      if entries = @memcache.get(uri_hash(a_request.uri))
        Marshal.load(entries)
      else
        Resourceful::CacheEntryCollection.new
      end
    end
  end
end
