require 'celluloid/io'
require 'http'
require 'resourceful/header'
require 'addressable/uri'

module Resourceful

  class CelluloidHttpAdapter
    # Make an HTTP request using the HTTP library
    #
    # Will use a proxy defined in the http_proxy environment variable, if set.
    #
    # @param [#read] body
    #   An IO-ish thing containing the body of the request
    #
    def make_request(method, uri, body = nil, header = {})

      options = {}
      options[:socket_class]     = Celluloid::IO::TCPSocket
      options[:ssl_socket_class] = Celluloid::IO::SSLSocket

      options[:body]     = body
      options[:headers]  = header
      options[:proxy]    = proxy if proxy = proxy_details
      options[:response] = :object

      client   = HTTP::Client.new(options)
      response = client.request(method, uri)

      [ response.code,
        Resourceful::Header.new(response.headers),
        response.body ]
    end

    private
    # Parse proxy details from http_proxy environment variable
    def proxy_details
      proxy = Addressable::URI.parse(ENV["http_proxy"])
      if proxy
        proxy_hash = {}
        proxy_hash[:proxy_address]  = proxy.host if proxy.host
        proxy_hash[:proxy_port]     = proxy.port if proxy.port
        proxy_hash[:proxy_username] = proxy.user if proxy.user
        proxy_hash[:proxy_password] = proxy.password if proxy.password

        if [2, 4].include?(proxy_hash.keys.size)
          proxy_hash
        else
          nil
        end
      else
        nil
      end
    end
  end
end
