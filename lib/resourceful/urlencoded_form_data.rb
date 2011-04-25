require 'resourceful/abstract_form_data'
require 'cgi'

module Resourceful
  class UrlencodedFormData < AbstractFormData

    def content_type
      "application/x-www-form-urlencoded"
    end

    # Read the form data encoded for putting on the wire.
    def read
      @form_data.map do |k,v|
        CGI.escape(k) + '=' + CGI.escape(v)
      end.join('&')
    end

  end
end
