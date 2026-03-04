# frozen_string_literal: true

Lapidary::Container.register_provider(:sentry) do
  prepare do
    require 'sentry/sequel'
  end

  start do
    require Lapidary.root.join('config/sentry').to_s

    if Sentry.initialized?
      target['database'].extension(:sentry)

      require_relative '../../lib/lapidary/sentry/ruby_llm_patch'
      require_relative '../../lib/lapidary/sentry/queue_patch'
      require_relative '../../lib/lapidary/sentry/queue_publish_patch'
      RubyLLM::Chat.prepend(Lapidary::Sentry::RubyLlmPatch)
      Lapidary::Analysis::BaseJob.prepend(Lapidary::Sentry::QueuePatch)
      Analysis::Repositories::JobRepository.prepend(Lapidary::Sentry::QueuePublishPatch)
    end
  end
end
