# frozen_string_literal: true

require_relative 'config/environment'

Lapidary::Container.finalize!
Lapidary::Container['migrator'].check

use Sentry::Rack::CaptureExceptions
run Lapidary::Web
