# frozen_string_literal: true

Sentry.init do |config|
  config.breadcrumbs_logger = %i[sentry_logger http_logger]
  config.traces_sample_rate = 1.0
  config.environment = Lapidary.config.env
  config.enabled_patches += %i[sequel]
end
