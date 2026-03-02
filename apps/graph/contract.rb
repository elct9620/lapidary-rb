# frozen_string_literal: true

require 'dry/validation'

module Graph
  # Validates query parameters for the graph neighbors endpoint
  class Contract < Dry::Validation::Contract
    NODE_ID_FORMAT = Lapidary::NodeId::FORMAT

    params do
      required(:node_id).filled(:string)
      optional(:direction).filled(:string)
      optional(:observed_after).filled(:string)
      optional(:observed_before).filled(:string)
      optional(:include_archived).filled(:bool)
    end

    rule(:node_id) do
      key.failure('must match type://name format') unless NODE_ID_FORMAT.match?(value)
    end

    rule(:direction) do
      key.failure('must be outbound, inbound, or both') if key? && !%w[outbound inbound both].include?(value)
    end

    register_macro(:iso8601_datetime) do
      Time.iso8601(value) if key?
    rescue ArgumentError
      key.failure('must be a valid ISO 8601 datetime')
    end

    rule(:observed_after).validate(:iso8601_datetime)
    rule(:observed_before).validate(:iso8601_datetime)
  end
end
