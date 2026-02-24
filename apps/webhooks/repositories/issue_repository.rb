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
        username, display_name = parse_author_name(issue_data.dig('author', 'name'))
        journals = (issue_data['journals'] || []).map { |j| build_journal(j) }

        Entities::Issue.new(
          id: issue_data['id'],
          subject: issue_data['subject'],
          author_username: username,
          author_display_name: display_name,
          journals: journals
        )
      end

      def build_journal(data)
        username, display_name = parse_author_name(data.dig('user', 'name'))

        Entities::Journal.new(
          id: data['id'],
          notes: data['notes'],
          author_username: username,
          author_display_name: display_name
        )
      end

      def parse_author_name(name)
        return [nil, nil] unless name

        match = name.match(/\A(.+?)\s*\((.+)\)\z/)
        if match
          [match[1].strip, match[2].strip]
        else
          [name.strip, nil]
        end
      end
    end
  end
end
