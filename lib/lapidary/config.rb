# auto_register: false
# frozen_string_literal: true

require 'dry/configurable'

module Lapidary
  # Centralized configuration for the application.
  class Config
    extend Dry::Configurable

    setting :env, default: ENV.fetch('RACK_ENV', 'development')

    setting :webhook do
      setting :secret, default: ENV.fetch('WEBHOOK_SECRET', nil)
    end

    setting :analysis do
      setting :job_retention, default: ENV.fetch('JOB_RETENTION', nil)
      setting :poll_interval, default: 1
      setting :cleanup_interval, default: 600
    end

    setting :graph do
      setting :retention, default: ENV.fetch('GRAPH_RETENTION', nil)
    end

    setting :redmine do
      setting :url, default: ENV.fetch('REDMINE_URL', 'https://bugs.ruby-lang.org')
      setting :timeout, default: 10
    end

    setting :openai do
      setting :api_key, default: ENV.fetch('OPENAI_API_KEY', nil)
      setting :model, default: ENV.fetch('OPENAI_MODEL', 'gpt-5-mini')
    end
  end
end
