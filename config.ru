# frozen_string_literal: true

require_relative 'config/environment'

Lapidary::Container.finalize!
Lapidary::Container['migrator'].check

proxy_cidrs = Lapidary.config.proxy.trusted
unless proxy_cidrs.empty?
  require 'ipaddr'
  proxy_ranges = proxy_cidrs.map { |cidr| IPAddr.new(cidr) }
  original_filter = Rack::Request.ip_filter
  Rack::Request.ip_filter = lambda { |ip|
    original_filter.call(ip) || proxy_ranges.any? { |range| range.include?(ip) rescue false } # rubocop:disable Style/RescueModifier
  }
end

use Sentry::Rack::CaptureExceptions
run Lapidary::Web
