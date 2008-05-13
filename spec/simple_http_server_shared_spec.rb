# this sets up a very simple http server using thin to be used in specs.
SimpleGet = lambda do |env|
  body = ["Hello, world!"]
  [ 200, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? SimpleGet

SimplePost = lambda do |env|
  body = [env['rack.input'].string]
  [ 201, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? SimplePost

SimplePut = lambda do |env|
  body = [env['rack.input'].string]
  [ 200, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? SimplePut

SimpleDel = lambda do |env|
  body = ["KABOOM!"]
  [ 200, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? SimpleDel

# has a response code of whatever it was given in the url /code/{123}
CodeResponder = lambda do |env|
  code = env['PATH_INFO'] =~ /([\d]+)/ ? Integer($1) : 404
  body = [code.to_s]

  [ code, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? CodeResponder

# redirect. /redirect/{301|302}?{url}
Redirector = lambda do |env|
  code = env['PATH_INFO'] =~ /([\d]+)/ ? Integer($1) : 404
  location = env['QUERY_STRING']
  body = [location]

  [ code, {'Content-Type' => 'text/plain', 'Location' => location, 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? Redirector


describe 'simple http server', :shared => true do
  before(:all) do
    #setup a thin http server we can connect to
    require 'thin'
    require 'rack'
    require 'rack/lobster'

    app = Rack::Builder.new do |env|
      use Rack::ShowExceptions

      map( '/get'    ){ run SimpleGet  }
      map( '/post'   ){ run SimplePost }
      map( '/put'    ){ run SimplePut  }
      map( '/delete' ){ run SimpleDel  }

      map( '/code'     ){ run CodeResponder }
      map( '/redirect' ){ run Redirector }
    end

    #spawn the server in a separate thread
    @httpd = Thread.new do
      Thin::Logging.silent = true
      #Thin::Logging.debug = true
      Thin::Server.start(app) 
    end
    #give the server a chance to initialize
    sleep 0.1
  end

  after(:all) do
    # kill the server thread
    @httpd.exit
  end


end