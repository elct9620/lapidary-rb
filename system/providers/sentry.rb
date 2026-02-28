# frozen_string_literal: true

Lapidary::Container.register_provider(:sentry) do
  prepare do
    require 'sentry/sequel'
  end

  start do
    require Lapidary.root.join('config/sentry').to_s
    target['database'].extension(:sentry) if Sentry.initialized?
  end
end
