module Resourceful
  class AbstractFormData
    def initialize(contents = {})
      @form_data = []
      
      contents.each do |k,v|
        add(k, v)
      end
    end

    # Add a name-value pair to this form data representation.
    #
    # @param [#to_s] name The name of the new name-value pair.
    # @param [#to_s] value The value of the new name-value pair.
    def add(name, value)
      form_data << [name.to_s, value]
    end

    # Resets representation so that #read can be called again.
    #
    # ----
    #
    # Form data representations do not need to be rewound so this is a no-op.
    def rewind
    end

    protected
    attr_reader :form_data
  end
end
