# auto_register: false
# frozen_string_literal: true

require 'async/service/managed/service'

module Lapidary
  module Analysis
    class Service < Async::Service::Managed::Service
      def run(_instance, _evaluator)
        Async do
          logger = Console.logger
          logger.info(self) { 'Analysis worker started' }

          loop do
            sleep 1
          end
        end
      end
    end
  end
end
