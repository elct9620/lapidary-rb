# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Value object representing arguments for an analysis job.
    JobArguments = Data.define(
      :entity_type, :entity_id, :content,
      :author_username, :author_display_name,
      :issue_id, :issue_content
    ) do
      def initialize(entity_type:, entity_id:, **rest)
        super(content: nil, author_username: nil, author_display_name: nil,
              issue_id: nil, issue_content: nil,
              entity_type: String(entity_type), entity_id: Integer(entity_id), **rest)
      end
    end
  end
end
