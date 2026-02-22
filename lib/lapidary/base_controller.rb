# frozen_string_literal: true

# auto_register: false

require 'sinatra/base'

module Lapidary
  # Base class for all Sinatra controllers
  class BaseController < Sinatra::Base
    set :environment, ENV.fetch('RACK_ENV', 'development').to_sym
    set :logging, false
    set :dump_errors, false
    set :show_exceptions, false
    set :raise_errors, false

    def container
      Lapidary::Container
    end

    def logger
      container['logger']
    end

    error do
      error = env['sinatra.error']
      logger.error(self, "#{error.class}: #{error.message}", error)

      content_type :json
      status 500
      JSON.generate(error: 'internal server error')
    end
  end
end
