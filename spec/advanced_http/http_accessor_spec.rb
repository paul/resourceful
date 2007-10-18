require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'advanced_http/http_accessor'

describe AdvancedHttp::HttpAccessor do 
  before do
    @logger = stub('logger')
    @authentication_info_provider = stub('authentication_info_provider')
    @accessor = AdvancedHttp::HttpAccessor.new(:authentication_info_provider => @authentication_info_provider,
                                               :logger => @logger)
  end
  
  it 'should be instantiatable' do
    AdvancedHttp::HttpAccessor.new().should be_instance_of(AdvancedHttp::HttpAccessor)
  end 
  
  it 'should accept logger to new' do
    ha = AdvancedHttp::HttpAccessor.new(:logger => (l = mock('logger')))
    
    ha.logger.should == l
  end 

  it 'should accept auth info provider in new()' do
    aip = mock('auth_info_provider')
    ha = AdvancedHttp::HttpAccessor.new(:authentication_info_provider => aip)
    
    ha.authentication_info_provider.should == aip
  end 
  
  it 'should allow authentication information provider to be registered' do 
    @accessor.authentication_info_provider = mock('auth_info_provider')
  end 
  
  it 'should allow a logger to be specified' do
    l = stub('logger')
    
    @accessor.logger = l
    @accessor.logger.should == l
  end 

  it 'should allow a logger to be removed' do
    l = stub('logger')
    
    @accessor.logger = l
    @accessor.logger = nil
    @accessor.logger.should be_nil    
  end 

  it 'should be able to return a particular resource (#[])' do
    @accessor['http://www.example/'].effective_uri.should == URI.parse('http://www.example/')
  end 

  it 'should create resource if it does not already exist (#[])' do
    AdvancedHttp::Resource.expects(:new).returns(stub('resource'))
    @accessor['http://www.example/previously-unused-uri']
  end 

  it 'should pass uri to resource upon creation (#[])' do
    AdvancedHttp::Resource.expects(:new).with('http://www.example/previously-unused-uri', anything).
      returns(stub('resource'))
    @accessor['http://www.example/previously-unused-uri']
  end 
  
  it 'should pass authentication_info_provider and logger to resource upon creation (#[])' do
    AdvancedHttp::Resource.expects(:new).with(anything, :auth_info => @authentication_info_provider, :logger => @logger).returns(stub('resource'))
    @accessor['http://www.example/previously-unused-uri']
  end 

  it 'should be able to return a particular resource (#resource)' do
    @accessor.resource('http://www.example/').effective_uri.should == URI.parse('http://www.example/')
  end 

  it 'should create resource if it does not already exist (#resource)' do
    AdvancedHttp::Resource.expects(:new).returns(stub('resource'))
    @accessor.resource('http://www.example/previously-unused-uri')
  end 

  it 'should pass authentication_info_provider and logger to resource upon creation (#[])' do
    AdvancedHttp::Resource.expects(:new).with(anything, :auth_info => @authentication_info_provider, :logger => @logger).returns(stub('resource'))
    @accessor.resource('http://www.example/previously-unused-uri')
  end 

  it 'should pass uri to resource upon creation (#resource)' do
    AdvancedHttp::Resource.expects(:new).with('http://www.example/previously-unused-uri', anything).
      returns(stub('resource'))
    @accessor.resource('http://www.example/previously-unused-uri')
  end 
end

describe AdvancedHttp::HttpAccessor, 'request stubbing' do
   before do
    @accessor = AdvancedHttp::HttpAccessor.new()
  end
  
  it 'should allow http request to be stubbed for testing/debugging purposes' do
    @accessor.stub_request(:get, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")    
  end 
  
  it 'should return request stubbing resource proxy' do
    @accessor.stub_request(:get, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")
    
    @accessor.resource('http://www.example/temptation-waits').should be_kind_of(AdvancedHttp::StubbedResourceProxy)
  end 

  it 'response to stubbed request should have canned body' do
    @accessor.stub_request(:get, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")
    
    @accessor.resource('http://www.example/temptation-waits').get.body.should == "This is a stubbed response"
  end
  
  it 'response to stubbed request should have canned content_type' do
    @accessor.stub_request(:get, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")
    
    @accessor.resource('http://www.example/temptation-waits').get['content-type'].should == "text/plain"
  end

  it 'should not allow stubbing of not get requests' do
    lambda{
      @accessor.stub_request(:post, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")
    }.should raise_error(ArgumentError)
    
  end 
end