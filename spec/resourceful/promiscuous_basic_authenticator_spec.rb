require File.expand_path("../spec_helper", File.dirname(__FILE__))

describe Resourceful::PromiscuousBasicAuthenticator do 
  before do 
    @authenticator = Resourceful::PromiscuousBasicAuthenticator.new('jim', 'mypasswd')
  end

  it "should always claim to be valid for a challenge response" do 
    challenge_resp = mock("a challenge response")
    @authenticator.valid_for?(challenge_resp).should eql(true)
  end

  it "should always claim to handle any request" do 
    a_req = mock("a  request")
    @authenticator.valid_for?(a_req).should eql(true)
  end

  it "be creatable with just a username and password" do 
    Resourceful::PromiscuousBasicAuthenticator.new('jim', 'mypasswd').should be_instance_of(Resourceful::PromiscuousBasicAuthenticator)
  end

  it "add credentials to request" do 
    header = mock('header')
    header.should_receive(:[]=).with("Authorization", "Basic amltOm15cGFzc3dk")
    a_req = mock("a  request", :header => header)

    @authenticator.add_credentials_to(a_req)
  end

end
