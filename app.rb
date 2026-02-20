# frozen_string_literal: true

require 'sinatra/base'
require_relative 'lib/lapidary/container'

# The main application
class App < Sinatra::Base
  def self.container
    Lapidary::Container
  end

  get '/' do
    'Hello World'
  end
end
