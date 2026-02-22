# frozen_string_literal: true

module Webhooks
  # Repository for fetching issues from the Redmine API.
  class IssueRepository
    include Lapidary::Dependency['redmine_api']

    def find(issue_id)
      data = redmine_api.fetch_issue(issue_id)
      build_issue(data)
    end

    private

    def build_issue(data)
      issue_data = data['issue']
      journals = (issue_data['journals'] || []).map { |j| Journal.new(id: j['id']) }
      Issue.new(id: issue_data['id'], journals: journals)
    end
  end
end
