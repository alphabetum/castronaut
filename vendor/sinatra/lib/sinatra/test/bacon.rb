require 'bacon'
require 'sinatra/test'

Sinatra::Default.set(
  :env => :test,
  :run => false,
  :raise_errors => true,
  :logging => false
)

module Sinatra::Test
  def should
    @response.should
  end
end

Bacon::Context.send(:include, Sinatra::Test)
