require 'securerandom'
require 'json'

%w{uuid validate task list}.each do |file|
  path = File.join(File.absolute_path(File.dirname(__FILE__)), 'nztodo', file)
  require path
end


