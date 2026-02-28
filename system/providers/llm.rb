# frozen_string_literal: true

Lapidary::Container.register_provider(:llm) do
  prepare do
    require 'async/http/faraday/default'
  end

  start do
    openai_config = Lapidary.config.openai
    RubyLLM.configure do |config|
      config.openai_api_key = openai_config.api_key
      config.default_model = openai_config.model
    end

    register('llm', RubyLLM)
  end
end
