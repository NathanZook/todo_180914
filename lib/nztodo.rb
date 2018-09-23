dirname = File.absolute_path(File.dirname(__FILE__))
require File.join(dirname, 'nztodo_core')
require 'sinatra'
require 'webrick/https'


module Sinatra
  class Application
    def self.run!
      certificate_content = File.open(ssl_certificate).read
      key_content = File.open(ssl_key).read

      server_options = {
        :Host => bind,
        :Port => port,
        :SSLEnable => true,
        :SSLCertificate => OpenSSL::X509::Certificate.new(certificate_content),
        :SSLPrivateKey => OpenSSL::PKey::RSA.new(key_content)
      }

      Rack::Handler::WEBrick.run self, server_options do |server|
        [:INT, :TERM].each { |sig| trap(sig) { server.stop } }
        server.threaded = settings.threaded if server.respond_to? :threaded=
        set :running, true
      end
    end
  end
end

cert_dir = File.absolute_path(File.join(dirname, '..', 'cert'))

set :port, ENV['PORT'] || 8443
set :ssl_certificate, File.join(cert_dir, 'server.crt')
set :ssl_key, File.join(cert_dir, 'server.key')
set :show_exceptions, :after_handler


def get_data(request)
  request.body.rewind
  JSON.parse(request.body.read)
rescue
  raise NZTodo::BadRequest, "Invalid json".to_json
end

get '/lists' do
  content_type :json
  NZTodo::List.list(params).to_json
end

post '/lists' do
  content_type :json
  ids = NZTodo::List.create(get_data(request))
  [201, {'id' => ids.first, 'task_ids' => ids.last}.to_json]
end

get '/list/:list_id' do |list_id|
  content_type :json
  NZTodo::List.retrieve(list_id).to_json
end

get '/list/:list_id/task/:task_id' do |list_id, task_id|
  content_type :json
  NZTodo::Task.retrieve(list_id, task_id).to_json
end

post '/list/:list_id/tasks' do |list_id|
  content_type :json
  task_id = NZTodo::Task.create(list_id, get_data(request))
  [201, task_id.to_json]
end

post '/list/:list_id/task/:task_id/complete' do |list_id, task_id|
  content_type :json
  task = NZTodo::Task.complete(list_id, task_id, get_data(request))
  [200, {'id' => task.id, 'completed' => task.completed}.to_json]
end

get '/test' do
  content_type :json
  `rspec -f j`
end

[
  [:get, "It's quiet out there.  Too quiet."],
  [:post, "You've got no horse and no cattle.  Just what do you think you are going to do with that post?"],
  [:head, "I've seen some folks with empty heads in my day.  This just takes the cake."],
  [:put, "You think you're just going to put that there?"],
  [:delete, "You think you can kill a man?  I'ld like to see you try."],
  [:options, "You don't know where you are going, and you want me to tell you how to get there?"],
  [:patch, "You keep working on that hole while the entire river is coming down at you."],
# [:connect, "I know you think that you can run your railroad through here.  But folks here don't see it that way."],
# [:trace, "It took those miners fifteen years to find their way though.  It's winter, and you want to try it yourself?"],
].each do |verb, message|
  send(verb, /.*/) do
    content_type :json
    if verb == :head
      404
    else
      [404, message.to_json]
    end
  end
end

