# frozen_string_literal: true

Lapidary::Container.register_provider(:webhook_secret) do
  start do
    register('webhook_secret', ENV.fetch('WEBHOOK_SECRET', nil))
  end
end
