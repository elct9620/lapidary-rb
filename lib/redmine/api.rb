# auto_register: false
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Redmine
  # HTTP client for the Redmine JSON API
  class API
    class FetchError < StandardError; end

    BASE_URL = 'https://bugs.ruby-lang.org'

    def fetch_issue(issue_id)
      url = URI("#{BASE_URL}/issues/#{issue_id}.json?include=journals")
      response = Net::HTTP.get_response(url)

      raise FetchError, "Failed to fetch #{url}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
      raise FetchError, "Failed to fetch #{url}: #{e.message}"
    end
  end
end
