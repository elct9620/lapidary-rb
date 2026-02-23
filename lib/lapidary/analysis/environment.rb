# auto_register: false
# frozen_string_literal: true

require 'async/service/managed/environment'

module Lapidary
  module Analysis
    module Environment
      include Async::Service::Managed::Environment

      def service_class
        Lapidary::Analysis::Service
      end

      def count
        1
      end

      def preload
        ['config/environment']
      end
    end
  end
end
