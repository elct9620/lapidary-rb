# frozen_string_literal: true

require_relative 'config/environment'

Lapidary::Container.finalize!
use Sentry::Rack::CaptureExceptions
run Lapidary::Web
