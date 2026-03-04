# auto_register: false
# frozen_string_literal: true

require 'async/service/managed/environment'

module Lapidary
  module Analysis
    # Falcon managed environment configuration for the analysis worker.
    module Environment
      include Async::Service::Managed::Environment

      def service_class
        Lapidary::Analysis::Worker
      end

      def count
        1
      end

      def preload
        ['config/environment']
      end

      # Finalize the container after fork to ensure a fresh database connection.
      # Falcon calls prepare! in the child process after forking from the parent.
      def prepare!(instance)
        Lapidary::Container.finalize!
        Lapidary::Container['migrator'].check
        super
      end
    end
  end
end
