require "spec_helper"
require 'tempfile'
require "resourceful/multipart_form_data.rb"

describe Resourceful::MultipartFormData do

  before do
    @form_data = Resourceful::MultipartFormData.new
  end

  it "should know its content-type" do
    @form_data.content_type.should match(/^multipart\/form-data/i)
  end

  it "should know its boundary string" do
    @form_data.content_type.should match(/; boundary=[0-9A-Za-z]{10,}/i)
  end

  it "should allow simple parameters to be added" do 
    @form_data.add(:foo, "testing")
  end

  describe "with multiple simple parameters" do 
    before do 
      @form_data.add('foo', 'bar')
      @form_data.add('baz', 'this')
    end

    it "should render a multipart form-data document when #read is called" do 
      boundary = /boundary=(\w+)/.match(@form_data.content_type)[1]
      @form_data.read.should eql(<<MPFD[0..-2])
--#{boundary}\r
Content-Disposition: form-data; name="foo"\r
\r
bar\r
--#{boundary}\r
Content-Disposition: form-data; name="baz"\r
\r
this\r
--#{boundary}--
MPFD
    end

    it "should be rewindable" do 
      first_read = @form_data.read
      @form_data.rewind
      @form_data.read.should eql(first_read)
    end

    it "should add file parameters to be added" do 
      Tempfile.open('resourceful-post-file-tests') do |file_to_upload|
        file_to_upload << "This is a test"
        file_to_upload.flush
        
        @form_data.add_file(:foo, file_to_upload.path)
      end
    end
  end

  describe "with file parameter" do 
    before do 
      @file_to_upload = Tempfile.new('resourceful-post-file-tests')
      @file_to_upload << "This is a test"
      @file_to_upload.flush
        
      @form_data.add_file(:foo, @file_to_upload.path)
    end

    it "should render a multipart form-data document when #read is called" do 
      boundary = /boundary=(\w+)/.match(@form_data.content_type)[1]
      @form_data.read.should eql(<<MPFD[0..-2])
--#{boundary}\r
Content-Disposition: form-data; name="foo"; filename="#{File.basename(@file_to_upload.path)}"\r
Content-Type: application/octet-stream\r
\r
This is a test\r
--#{boundary}--
MPFD

    end
      
  end
end

