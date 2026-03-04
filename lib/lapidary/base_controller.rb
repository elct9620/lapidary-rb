# frozen_string_literal: true

# auto_register: false

require 'sinatra/base'

module Lapidary
  # Base class for all Sinatra controllers
  class BaseController < Sinatra::Base
    set :environment, Lapidary.config.env.to_sym
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

    def respond_json(body)
      content_type :json
      JSON.generate(body)
    end

    def halt_json(status_code, body)
      halt status_code, { 'Content-Type' => 'application/json' }, JSON.generate(body)
    end

    def dispatch_background(&)
      if defined?(Async::Task) && Async::Task.current?
        dispatch_async_background(&)
      else
        yield
      end
    end

    private

    def dispatch_async_background
      sentry_headers = ::Sentry.initialized? ? ::Sentry.get_trace_propagation_headers : nil
      Async(transient: true) do
        transaction = continue_background_trace(sentry_headers)
        yield
      rescue StandardError => e
        ::Sentry.capture_exception(e)
        logger.error(self, "Background processing failed: #{e.class}: #{e.message}")
      ensure
        transaction&.finish
      end
    end

    def continue_background_trace(sentry_headers)
      return unless sentry_headers

      transaction = ::Sentry.continue_trace(sentry_headers, op: 'background.process', name: self.class.name)
      ::Sentry.get_current_scope&.set_span(transaction) if transaction
      transaction
    end

    def validate_with_contract!(contract_key, input, status: 422)
      result = container[contract_key].call(input)

      if result.failure?
        logger.warn(self, 'Validation failed')
        halt_json status, errors: result.errors.to_h
      end

      result
    end

    not_found do
      respond_json(error: 'not found') unless response['Content-Type']&.include?('application/json')
    end

    error do
      error = env['sinatra.error']
      ::Sentry.capture_exception(error)
      logger.error(self, "#{error.class}: #{error.message}")

      status 500
      respond_json(error: 'internal server error')
    end
  end
end
