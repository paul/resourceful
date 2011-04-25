require 'pathname'
require 'benchmark'
require 'resourceful/response'
require 'resourceful/net_http_adapter'
require 'resourceful/exceptions'

module Resourceful

  class Request

    REDIRECTABLE_METHODS = [:get, :head]
    CACHEABLE_METHODS = [:get, :head]
    INVALIDATING_METHODS = [:post, :put, :delete]

    attr_accessor :method, :resource, :body, :header
    attr_reader   :request_time, :accessor

    # @param [Symbol] http_method
    #   :get, :put, :post, :delete or :head
    # @param [Resourceful::Resource] resource
    # @param [#read, #rewind] body
    # @param [Resourceful::Header, Hash] header
    def initialize(http_method, resource, body = nil, header = nil)
      @method, @resource, @body = http_method, resource, body
      @accessor = @resource.accessor
      @header = header.is_a?(Resourceful::Header) ? header : Resourceful::Header.new(header)

      # Resourceful handled gzip encoding transparently, so set that up
      @header.accept_encoding ||= 'gzip, identity'

      # 'Host' is a required HTTP/1.1 header, overrides Host in user-provided headers
      @header.host = @resource.host

      # Setting the date isn't a bad idea, either
      @header.date ||= Time.now.httpdate

      # Add any auth credentials we might want
      add_credentials!

    end

    # Uses the auth manager to add any valid credentials to this request
    def add_credentials!
      @accessor.auth_manager.add_credentials(self)
    end

    # Performs all the work. Handles caching, redirects, auth retries, etc
    def fetch_response
      if cached_response
        if needs_revalidation?(cached_response)
          logger.info("    Cache needs revalidation")
          set_validation_headers!(cached_response)
        else
          # We're done!
          return cached_response
        end
      end

      response = perform!

      response = revalidate_cached_response(response) if cached_response && response.not_modified?
      response = follow_redirect(response)            if should_be_redirected?(response)
      response = retry_with_auth(response)            if needs_authorization?(response)

      raise UnsuccessfulHttpRequestError.new(self, response) if response.error?

      if cacheable?(response)
        store_in_cache(response)
      elsif invalidates_cache?
        invalidate_cache
      end

      return response
    end

    # Should we look for a response to this request in the cache?
    def skip_cache?
      return true unless method.in? CACHEABLE_METHODS
      header.cache_control && header.cache_control.include?('no-cache')
    end

    # The cached response
    def cached_response
      return if skip_cache?
      return if @cached_response.nil? && @already_checked_cache
      @cached_response ||= begin
        @already_checked_cache = true
        resp = accessor.cache_manager.lookup(self)
        logger.info("    Retrieved from cache") if resp
        resp
      end
    end

    # Revalidate the cached response with what we got from a 304 response
    def revalidate_cached_response(not_modified_response)
      logger.info("    Resource not modified")
      cached_response.revalidate!(not_modified_response)
      cached_response
    end

    # Follow a redirect response
    def follow_redirect(response)
      raise MalformedServerResponse.new(self, response) unless response.header.location
      if response.moved_permanently?
        new_uri = response.header.location
        logger.info("    Permanently redirected to #{new_uri} - Storing new location.")
        resource.update_uri new_uri
        @header.host = resource.host
        response = fetch_response
      elsif response.see_other? # Always use GET for this redirect, regardless of initial method
        redirected_resource = Resourceful::Resource.new(self.accessor, response.header['Location'])
        response = Request.new(:get, redirected_resource, body, header).fetch_response
      else
        redirected_resource = Resourceful::Resource.new(self.accessor, response.header['Location'])
        logger.info("    Redirected to #{redirected_resource.uri} - Caching new location.")
        response = Request.new(method, redirected_resource, body, header).fetch_response
      end
    end

    # Add any auth headers from the response to the auth manager, and try the request again
    def retry_with_auth(response)
      @already_tried_with_auth = true
      logger.info("Authentication Required. Retrying with auth info")
      accessor.auth_manager.associate_auth_info(response)
      add_credentials!
      @body.rewind if @body # Its a stringIO, and we already fed it to the adapter once, so rewind it when we try again
      response = fetch_response
    end

    # Does this request need to be authorized? Will only be true if we haven't already tried with auth
    def needs_authorization?(response)
      !@already_tried_with_auth && response.unauthorized?
    end

    # Store the response to this request in the cache
    def store_in_cache(response)
      # RFC2618 - 14.18 : A received message that does not have a Date header
      # field MUST be assigned one by the recipient if the message will be cached
      # by that recipient.
      response.header.date ||= response.response_time.httpdate

      accessor.cache_manager.store(self, response)
    end

    # Invalidated the cache for this uri (eg, after a POST)
    def invalidate_cache
      accessor.cache_manager.invalidate(resource.uri)
    end

    # Is this request & response permitted to be stored in this (private) cache?
    def cacheable?(response)
      return false unless response.success?
      return false unless method.in? CACHEABLE_METHODS
      return false if header.cache_control && header.cache_control.include?('no-store')
      true
    end

    # Does this request invalidate the cache?
    def invalidates_cache?
      return true if method.in? INVALIDATING_METHODS
    end

    # Perform the request, with no magic handling of anything.
    def perform!
      @request_time = Time.now

      http_resp = adapter.make_request(@method, @resource.uri, @body, @header)
      @response = Resourceful::Response.new(uri, *http_resp)
      @response.request_time = @request_time
      @response.authoritative = true

      @response
    end

    # Is this a response a redirect, and are we permitted to follow it?
    def should_be_redirected?(response)
      return false unless response.redirect?
      if resource.on_redirect.nil?
        return true if method.in? REDIRECTABLE_METHODS
        false
      else
        resource.on_redirect.call(self, response)
      end
    end

    # Do we need to revalidate our cache?
    def needs_revalidation?(response)
      return true if forces_revalidation?
      return true if response.stale?
      return true if max_age && response.current_age > max_age
      return true if response.must_be_revalidated?
      false
    end

    # Set the validation headers of a request based on the response in the cache
    def set_validation_headers!(response)
      @header['If-None-Match'] = response.header['ETag'] if response.header.has_key?('ETag')
      @header['If-Modified-Since'] = response.header['Last-Modified'] if response.header.has_key?('Last-Modified')
      @header['Cache-Control'] = 'max-age=0' if response.must_be_revalidated?
    end

    # @return [String]   The URI against which this request will be, or was, made.
    def uri
      resource.uri
    end

    # Does this request force us to revalidate the cache?
    def forces_revalidation?
      if max_age == 0 || skip_cache?
        logger.info("    Client forced revalidation")
        true
      else
        false
      end
    end

    # Indicates the maxmimum response age in seconds we are willing to accept
    #
    # Returns nil if we don't care how old the response is
    def max_age
      if header['Cache-Control'] and header['Cache-Control'].include?('max-age')
        header['Cache-Control'].split(',').grep(/max-age/).first.split('=').last.to_i
      end
    end

    def logger
      resource.logger
    end

    def adapter
      accessor.http_adapter
    end
  end

end
