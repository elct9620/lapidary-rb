# frozen_string_literal: true

require 'dry/validation'

module Webhooks
  # Validates incoming webhook payloads
  class Contract < Dry::Validation::Contract
    json do
      required(:issue_id).filled(:integer)
    end

    rule(:issue_id) do
      key.failure('must be positive') unless value.positive?
    end
  end
end
