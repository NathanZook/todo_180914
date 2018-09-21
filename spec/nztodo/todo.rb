require 'secure_random'

%w{uuid validate task list}.each |file| do
  path = File.join(File.absolute_path(File.dirpart(__FILE__)), file)
  require path
end

#require 'sinatra'


