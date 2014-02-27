require 'net/http'
require 'time'
require 'zlib'

module Resourceful

  class Response
    REDIRECT_RESPONSE_CODES = [301,302,303,307]
    NORMALLY_CACHEABLE_RESPONSE_CODES = [200, 203, 300, 301, 410]

    attr_reader :uri, :code, :header, :body, :response_time
    alias headers header

    attr_accessor :authoritative, :request_time
    alias authoritative? authoritative

    def initialize(uri, code, header, body)
      @uri, @code, @header, @body = uri, code, header, body
      @response_time = Time.now
    end

    # Is this a cached response that has expired?
    #
    # @return true|false
    def expired?
      if header.cache_control and m_age_str = header.cache_control.find{|cc| /^max-age=/ === cc}
        return current_age > m_age_str[/\d+/].to_i
      elsif header.expires
        return Time.httpdate(header.expires) < Time.now
      end

      false
    end

    # Is this a cached response that is stale?
    #
    # @return true|false
    def stale?
      return true if expired?
      return false unless header.has_field?(Header::CACHE_CONTROL)
      return true if header.cache_control.any?{|cc| /must-revalidate|no-cache/ === cc}

      false
    end

    # Is this response cachable?
    #
    # @return true|false
    def cacheable?
      @cacheable ||= begin
        @cacheable = true  if NORMALLY_CACHEABLE_RESPONSE_CODES.include?(code.to_i)
        @cacheable = false if header.vary && header.vary.include?('*')
        @cacheable = false if header.cache_control && header.cache_control.include?('no-cache')
        @cacheable = true  if header.cache_control && header.cache_control.include?('public')
        @cacheable = true  if header.cache_control && header.cache_control.include?('private')
        @cacheable = false if header.expires && header.expires.to_i < 0
        @cacheable || false
      end
    end

    # Does this response force revalidation?
    def must_be_revalidated?
      header.cache_control && header.cache_control.include?('must-revalidate')
    end

    # Update our headers from a later 304 response
    def revalidate!(not_modified_response)
      header.merge!(not_modified_response.header)
      @request_time  = not_modified_response.request_time
      @response_time = not_modified_response.response_time
      @authoritative = true
    end

    # Algorithm taken from RCF2616#13.2.3
    def current_age
      age_value   = header.age.to_i
      date_value  = Time.httpdate(header.date)
      now         = Time.now

      apparent_age = [0, response_time - date_value].max
      corrected_received_age = [apparent_age, age_value].max
      current_age = corrected_received_age + (response_time - request_time) + (now - response_time)
    end

    def body
      raise(NotImplementedError, 'Chained encodings are not supported') if header['Content-Encoding'] && header['Content-Encoding'].length > 1
      encoding = header['Content-Encoding'] && header['Content-Encoding'].first

      case encoding
      when nil
        # body is identity encoded; just return it
        @body
      when /^\s*gzip\s*$/i
        gz_in = ::Zlib::GzipReader.new(StringIO.new(@body, 'r'))
        @body = gz_in.read
        gz_in.close
        header.delete('Content-Encoding')
        @body
      else
        raise UnsupportedContentCoding, "Resourceful does not support #{encoding} content coding"
      end
    end

    CODE_NAMES = {
      100 => "Continue".freeze,
      101 => "Switching Protocols".freeze,

      200 => "OK".freeze,
      201 => "Created".freeze,
      202 => "Accepted".freeze,
      203 => "Non-Authoritative Information".freeze,
      204 => "No Content".freeze,
      205 => "Reset Content".freeze,
      206 => "Partial Content".freeze,

      300 => "Multiple Choices".freeze,
      301 => "Moved Permanently".freeze,
      302 => "Found".freeze,
      303 => "See Other".freeze,
      304 => "Not Modified".freeze,
      305 => "Use Proxy".freeze,
      307 => "Temporary Redirect".freeze,

      400 => "Bad Request".freeze,
      401 => "Unauthorized".freeze,
      402 => "Payment Required".freeze,
      403 => "Forbidden".freeze,
      404 => "Not Found".freeze,
      405 => "Method Not Allowed".freeze,
      406 => "Not Acceptable".freeze,
      407 => "Proxy Authentication Required".freeze,
      408 => "Request Timeout".freeze,
      409 => "Conflict".freeze,
      410 => "Gone".freeze,
      411 => "Length Required".freeze,
      412 => "Precondition Failed".freeze,
      413 => "Request Entity Too Large".freeze,
      414 => "Request-URI Too Long".freeze,
      415 => "Unsupported Media Type".freeze,
      416 => "Requested Range Not Satisfiable".freeze,
      417 => "Expectation Failed".freeze,

      500 => "Internal Server Error".freeze,
      501 => "Not Implemented".freeze,
      502 => "Bad Gateway".freeze,
      503 => "Service Unavailable".freeze,
      504 => "Gateway Timeout".freeze,
      505 => "HTTP Version Not Supported".freeze,
    }.freeze

    CODES = CODE_NAMES.keys

    CODE_NAMES.each do |code, msg|
      method_name = msg.downcase.gsub(/[- ]/, "_")

      class_eval <<-RUBY
        def #{method_name}?                           # def ok?
          @code == #{code}                            #   @code == 200
        end                                           # end
      RUBY
    end

    # Is the response informational? True for
    # 1xx series response codes
    #
    # @return true|false
    def informational?
      @code.in? 100..199
    end

    # Is the response code sucessful? True for only 2xx series
    # response codes.
    #
    # @return true|false
    def successful?
      @code.in? 200..299
    end
    alias success? successful?

    # Is the response a redirect? True for
    # 3xx series response codes
    #
    # @return true|false
    def redirection?
      @code.in? 300..399
    end

    # Is the response a actual redirect? True for
    # 301, 302, 303, 307 response codes
    #
    # @return true|false
    def redirect?
      @code.in? REDIRECT_RESPONSE_CODES
    end

    # Is the response the result of a client error? True for
    # 4xx series response codes
    #
    # @return true|false
    def client_error?
      @code.in? 400..499
    end

    # Is the response the result of a server error? True for
    # 5xx series response codes
    #
    # @return true|false
    def server_error?
      @code.in? 500..599
    end

    # Is the response the result of any kind of error? True for
    # 4xx and 5xx series response codes
    #
    # @return true|false
    def error?
      server_error? || client_error?
    end

  end

end
