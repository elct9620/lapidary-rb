# frozen_string_literal: true

require 'dry/validation'

module Graph
  # Validates query parameters for the graph neighbors endpoint
  class Contract < Dry::Validation::Contract
    NODE_ID_FORMAT = %r{\A[a-z_]+://\S+\z}

    params do
      required(:node_id).filled(:string)
      optional(:direction).filled(:string)
      optional(:observed_after).filled(:string)
      optional(:observed_before).filled(:string)
    end

    rule(:node_id) do
      key.failure('must match type://name format') unless NODE_ID_FORMAT.match?(value)
    end

    rule(:direction) do
      key.failure('must be outbound, inbound, or both') if key? && !%w[outbound inbound both].include?(value)
    end

    rule(:observed_after) do
      Time.iso8601(value) if key?
    rescue ArgumentError
      key.failure('must be a valid ISO 8601 datetime')
    end

    rule(:observed_before) do
      Time.iso8601(value) if key?
    rescue ArgumentError
      key.failure('must be a valid ISO 8601 datetime')
    end
  end
end
