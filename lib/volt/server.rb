require 'opal'
require "rack"
if RUBY_PLATFORM != 'java'
  require "rack/sockjs"
  require "eventmachine"
end
require "sprockets-sass"
require "sass"

require 'volt/extra_core/extra_core'
require 'volt/server/component_handler'
if RUBY_PLATFORM != 'java'
  require 'volt/server/channel_handler'
end
require 'volt/server/rack/asset_files'
require 'volt/server/rack/index_files'
require 'volt/server/rack/opal_files'


class Server
  def initialize
    @app_path = File.expand_path(File.join(Dir.pwd, "app"))
    @asset_files = AssetFiles.new
  end
  
  def app
    @app = Rack::Builder.new
    @app.use Rack::CommonLogger
    @app.use Rack::ShowExceptions

    @app.map '/components' do
      run ComponentHandler.new
    end

    # Serve the main html files from public, also figure out
    # which JS/CSS files to serve.
    @app.use IndexFiles, @asset_files
    
    # Serve the opal files
    OpalFiles.new(@app, @app_path, @asset_files)
    
    # Handle socks js connection
    if RUBY_PLATFORM != 'java'
      @app.map "/channel" do
        run Rack::SockJS.new(ChannelHandler)#, :websocket => false
      end
    end
    
    @app.use Rack::Static,
      :urls => ["/"],
      :root => "public",
      :index => "",
      :header_rules => [
        [:all, {'Cache-Control' => 'public, max-age=86400'}]
      ]

    @app.run lambda{ |env| [ 404, { 'Content-Type'  => 'text/html' }, ['404 - page not found'] ] }
    
    return @app
  end
end