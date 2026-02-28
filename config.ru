# frozen_string_literal: true

require_relative 'config/environment'

use Sentry::Rack::CaptureExceptions
run Lapidary::Web
