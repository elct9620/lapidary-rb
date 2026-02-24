# auto_register: false
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Redmine
  # HTTP client for the Redmine JSON API
  class API
    class FetchError < StandardError; end

    DEFAULT_TIMEOUT = 10

    def initialize(base_url: 'https://bugs.ruby-lang.org', open_timeout: DEFAULT_TIMEOUT, read_timeout: DEFAULT_TIMEOUT)
      @base_url = base_url
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def fetch_issue(issue_id)
      url = URI("#{@base_url}/issues/#{issue_id}.json?include=journals")
      response = build_http(url).request(Net::HTTP::Get.new(url))

      raise FetchError, "Failed to fetch #{url}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
      raise FetchError, "Failed to fetch #{url}: #{e.message}"
    end

    private

    def build_http(url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = url.scheme == 'https'
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http
    end
  end
end
