# frozen_string_literal: true

Sentry.init do |config|
  config.breadcrumbs_logger = %i[sentry_logger http_logger]
  config.traces_sampler = lambda { |sampling_context|
    rack_env = sampling_context[:env]
    return 1.0 unless rack_env

    rack_env['PATH_INFO'] == '/' ? 0.0 : 1.0
  }
  config.environment = Lapidary.config.env
  config.enabled_patches += %i[sequel]
end
