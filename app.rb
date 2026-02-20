# frozen_string_literal: true

require 'sinatra/base'

# The main application
class App < Sinatra::Base
  get '/' do
    'Hello World'
  end
end
