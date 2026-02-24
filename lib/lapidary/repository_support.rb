# frozen_string_literal: true

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
        define_method(:with_error_wrapping) do |&block|
          block.call
        rescue Sequel::Error => e
          raise error_class, e.message
        end
        private :with_error_wrapping
      end
    end
  end
end
