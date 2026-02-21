# frozen_string_literal: true

# auto_register: false

require 'sinatra/base'

module Lapidary
  # Base class for all Sinatra controllers
  class BaseController < Sinatra::Base
    set :environment, ENV.fetch('RACK_ENV', 'development').to_sym
  end
end
