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
        author = parse_author(issue_data.dig('author', 'name'))
        journals = (issue_data['journals'] || []).map { |j| build_journal(j) }

        Entities::Issue.new(
          id: issue_data['id'],
          subject: issue_data['subject'],
          author: author,
          created_on: issue_data['created_on'],
          journals: journals
        )
      end

      def build_journal(data)
        author = parse_author(data.dig('user', 'name'))

        Entities::Journal.new(
          id: data['id'],
          notes: data['notes'],
          author: author,
          created_on: data['created_on']
        )
      end

      def parse_author(name)
        return nil unless name

        match = name.match(/\A(.+?)\s*\((.+)\)\z/)
        if match
          Entities::Author.new(username: match[1].strip, display_name: match[2].strip)
        else
          Entities::Author.new(username: name.strip, display_name: nil)
        end
      end
    end
  end
end
