# frozen_string_literal: true

Lapidary::Container.register_provider(:llm) do
  prepare do
    require 'ruby_llm'
  end

  start do
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
      config.default_model = ENV.fetch('OPENAI_MODEL', 'gpt-5-mini')
    end

    register('llm', RubyLLM)
  end
end
