require "spec_helper"
require 'tempfile'
require "resourceful/urlencoded_form_data.rb"

describe Resourceful::UrlencodedFormData do

  before do
    @form_data = Resourceful::UrlencodedFormData.new
  end

  it "should know its content-type" do
    @form_data.content_type.should match(/^application\/x-www-form-urlencoded$/i)
  end

  describe "instantiation" do
    it "should be creatable with hash" do
      Resourceful::UrlencodedFormData.new(:foo => 'testing').read.should eql("foo=testing")
    end
  end

  it "should allow simple parameters to be added" do 
    @form_data.add(:foo, "testing")
  end

  describe "with multiple items" do 
    before do 
      @form_data.add('foo', 'bar')
      @form_data.add('baz', 'this')
    end

    it "should render itself correctly" do 
      @form_data.read.should eql("foo=bar&baz=this")
    end

    it "should be rewindable" do 
      first = @form_data.read
      @form_data.rewind
      
      @form_data.read.should eql(first)
    end    
  end

  describe "with unsafe characters in name" do 
    before do 
      @form_data.add('foo=bar', 'this')
    end

    it "should render itself correctly" do 
      @form_data.read.should eql("foo%3Dbar=this")
    end
  end


  describe "with unsafe characters in value" do 
    before do 
      @form_data.add('foo', 'this & that')
    end

    it "should render itself correctly" do 
      @form_data.read.should eql("foo=this+%26+that")
    end
  end

end
