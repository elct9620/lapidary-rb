# frozen_string_literal: true

module Webhooks
  module Repositories
    # Repository for fetching issues from the Redmine API.
    class IssueRepository
      include Lapidary::Dependency['redmine_api']

      def find(issue_id)
        data = redmine_api.fetch_issue(issue_id)
        build_issue(data)
      rescue Redmine::API::FetchError => e
        raise Entities::IssueFetchError, e.message
      end

      private

      def build_issue(data)
        issue_data = data['issue']
        journals = (issue_data['journals'] || []).map { |j| Entities::Journal.new(id: j['id']) }
        Entities::Issue.new(id: issue_data['id'], journals: journals)
      end
    end
  end
end
