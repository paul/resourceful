module Resourceful  
  # This class provides HTTP basic authentication without regard to
  # the realm of receiving resource.  This will send your username and
  # password with any request made while it is in play.
  class PromiscuousBasicAuthenticator < BasicAuthenticator
    def initialize(username, password)
      super(nil, username, password)
    end
    
    def valid_for?(challenge_response)
      true
    end

    def can_handle?(request)
      true
    end
  end
end
