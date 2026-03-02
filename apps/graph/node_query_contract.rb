# frozen_string_literal: true

require 'dry/validation'

module Graph
  # Validates query parameters for the graph nodes listing endpoint
  class NodeQueryContract < Dry::Validation::Contract
    # Must match Analysis::Entities::NodeType::ALL — kept as literal to avoid cross-BC dependency
    VALID_TYPES = %w[Rubyist CoreModule Stdlib].freeze

    params do
      optional(:type).filled(:string)
      optional(:q).filled(:string)
      optional(:limit).filled(:integer)
      optional(:offset).filled(:integer)
      optional(:include_orphans).filled(:bool)
    end

    rule(:type) do
      key.failure('must be Rubyist, CoreModule, or Stdlib') if key? && !VALID_TYPES.include?(value)
    end

    rule(:limit) do
      key.failure('must be between 1 and 100') if key? && !value.between?(1, 100)
    end

    rule(:offset) do
      key.failure('must be non-negative') if key? && value.negative?
    end
  end
end
