# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'LLM provider' do
  it 'registers llm in the container' do
    expect(Lapidary::Container['llm']).to eq(RubyLLM)
  end

  it 'configures the default model' do
    Lapidary::Container['llm']
    expect(RubyLLM.config.default_model).to eq('gpt-5-mini')
  end
end
