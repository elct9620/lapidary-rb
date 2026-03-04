# auto_register: false
# frozen_string_literal: true

module Analysis
  module Entities
    # Value object representing arguments for an analysis job.
    JobArguments = Data.define(
      :entity_type, :entity_id, :title, :content,
      :author_username, :author_display_name,
      :issue_id, :issue_title, :issue_content,
      :issue_author_username, :issue_author_display_name,
      :created_on
    ) do
      def initialize(entity_type:, entity_id:, **rest)
        super(title: nil, content: nil, author_username: nil, author_display_name: nil,
              issue_id: nil, issue_title: nil, issue_content: nil,
              issue_author_username: nil, issue_author_display_name: nil, created_on: nil,
              entity_type: String(entity_type), entity_id: Integer(entity_id), **rest)
      end
    end
  end
end
