
__DIR__ = File.dirname(__FILE__)

$LOAD_PATH.unshift __DIR__ unless
  $LOAD_PATH.include?(__DIR__) ||
  $LOAD_PATH.include?(File.expand_path(__DIR__))

require 'resourceful/util'

require 'resourceful/header'
require 'resourceful/http_accessor'
require 'resourceful/simple'

module Resourceful
  autoload :MultipartFormData, 'resourceful/multipart_form_data'
  autoload :UrlencodedFormData, 'resourceful/urlencoded_form_data'
  autoload :StubbedResourceProxy, 'resourceful/stubbed_resource_proxy'
  autoload :PromiscuousBasicAuthenticator, 'resourceful/promiscuous_basic_authenticator'

  extend Simple
end

# Resourceful is a library that provides a high level HTTP interface.
module Resourceful
  VERSION = "1.1.0"
  RESOURCEFUL_USER_AGENT_TOKEN = "Resourceful/#{VERSION}(Ruby/#{RUBY_VERSION})"
end
