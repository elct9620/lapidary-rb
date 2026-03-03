# frozen_string_literal: true

Sentry.init do |config|
  config.send_default_pii = true
  config.breadcrumbs_logger = %i[sentry_logger http_logger]
  config.traces_sampler = lambda { |sampling_context|
    rack_env = sampling_context[:env]
    return 1.0 unless rack_env

    rack_env['PATH_INFO'] == '/' ? 0.0 : 1.0
  }
  config.trusted_proxies += Lapidary.config.proxy.trusted
  config.environment = Lapidary.config.env
  config.enabled_patches += %i[sequel]
end
