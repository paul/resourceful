require File.dirname(__FILE__) + "/../spec_helper"
require 'advanced_http/options_interpreter'

describe AdvancedHttp::OptionsInterpreter, '#initialize' do
  it 'should be creatable block' do
    AdvancedHttp::OptionsInterpreter.new() {}
  end 
end 


describe AdvancedHttp::OptionsInterpreter, "#option()" do
  before do
    @interpreter = AdvancedHttp::OptionsInterpreter.new()
  end
  
  it 'should take option name' do
    @interpreter.option(:test)
    @interpreter.supported_options.should include(:test)
  end 

  it 'should take interpretation block' do
    @interpreter.option(:test) {"this"}
    @interpreter.supported_options.should include(:test)
  end 
end 

describe AdvancedHttp::OptionsInterpreter, '#interpret(options)' do
  before do
    @interpreter = AdvancedHttp::OptionsInterpreter.new()
    @interpreter.option(:foo)
  end
  
  it 'should return hash like structure of interpreted options' do
    opts = @interpreter.interpret(:foo => 'bar')
    
    opts.should have_key(:foo)
    opts[:foo].should == 'bar'
  end 
  
  it 'should raise argument error if there is an unsupported option in src hash' do
    lambda {
      @interpreter.interpret(:bar => 'baz')
    }.should raise_error(ArgumentError, "Unrecognized options: bar")
  end

  it 'should list all unsupported options in the exception' do
    lambda {
      @interpreter.interpret(:bar => 'baz', :baz => 'bar')
    }.should raise_error(ArgumentError, /Unrecognized options: (bar, baz)|(baz, bar)/)
  end

  it 'should execute pass the options though the appropriate handling block' do
    @interpreter.option(:foo) {|foo| foo + " hello"}
    
    @interpreter.interpret(:foo => 'bar')[:foo].should == 'bar hello'
  end 
  
  it 'should not include options that were not passed in resulting hash' do
    @interpreter = AdvancedHttp::OptionsInterpreter.new()
    @interpreter.option(:foo)
    
    @interpreter.interpret({}).keys.should_not include(:foo)
  end 

  it 'should not invoked option value munging block if option is not specified'
  
  it 'should use default if option is not specified' do
    @interpreter = AdvancedHttp::OptionsInterpreter.new()
    @interpreter.option(:foo, :default => 'hello')

    opts = @interpreter.interpret({})
    opts.should have_key(:foo)
    opts[:foo].should == 'hello'
  end 

  it 'should use default value if option is specified as nil' do
    @interpreter = AdvancedHttp::OptionsInterpreter.new()
    @interpreter.option(:foo, :default => 'hello')

    opts = @interpreter.interpret({:foo => nil})
    opts.should have_key(:foo)
    opts[:foo].should == 'hello'
  end 

  it 'should not use default if option is specified ' do
    @interpreter = AdvancedHttp::OptionsInterpreter.new()
    @interpreter.option(:foo, :default => 'hello')

    opts = @interpreter.interpret({:foo => 'bye'})
    opts.should have_key(:foo)
    opts[:foo].should == 'bye'
  end 

end 