# frozen_string_literal: true

require 'json'

module Lapidary
  # Mixin providing declarative DSL for repository boilerplate.
  module RepositorySupport
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level DSL methods for repository configuration.
    module ClassMethods
      def table(name)
        define_method(:dataset) { database[name] }
        private :dataset
      end

      def wraps_errors(error_class)
        # Uses block.call instead of yield because yield is not available
        # inside define_method blocks (no implicit block forwarding).
        define_method(:with_error_wrapping) do |&block|
          block.call
        rescue Sequel::Error => e
          raise error_class, e.message
        end
        private :with_error_wrapping
      end
    end

    private

    def parse_json(json_string, default: {})
      json_string ? JSON.parse(json_string, symbolize_names: true) : default
    end

    def generate_json(data)
      JSON.generate(data)
    end
  end
end
