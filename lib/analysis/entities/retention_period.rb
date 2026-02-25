# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Immutable value object representing a job retention period for cleanup.
    RetentionPeriod = Data.define(:amount, :unit) do
      def self.parse(value)
        return nil unless value.is_a?(String)

        match = value.match(/\A(\d+)([a-z])\z/)
        return nil unless match && RetentionPeriod::VALID_UNITS.include?(match[2])

        new(amount: Integer(match[1]), unit: match[2])
      end

      def self.default
        new(amount: 7, unit: 'd')
      end

      def cutoff(now: Time.now)
        now - (amount * RetentionPeriod::SECONDS_PER_UNIT.fetch(unit))
      end

      def to_s
        "#{amount}#{unit}"
      end
    end

    class RetentionPeriod
      VALID_UNITS = %w[h d].freeze
      SECONDS_PER_UNIT = { 'h' => 3600, 'd' => 86_400 }.freeze
    end
  end
end
