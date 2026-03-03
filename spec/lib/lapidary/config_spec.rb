# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lapidary::Config do
  describe '.config' do
    subject(:config) { described_class.config }

    it 'returns the config object' do
      expect(config).to be_a(Dry::Configurable::Config)
    end
  end

  describe 'Lapidary.config' do
    it 'delegates to Config.config' do
      expect(Lapidary.config).to eq(described_class.config)
    end
  end

  describe 'env' do
    it 'returns the current RACK_ENV' do
      expect(Lapidary.config.env).to eq('test')
    end
  end

  describe 'webhook' do
    it 'has a secret setting' do
      expect(Lapidary.config.webhook).to respond_to(:secret)
    end
  end

  describe 'analysis' do
    it 'has a job_retention setting' do
      expect(Lapidary.config.analysis).to respond_to(:job_retention)
    end

    it 'has a poll_interval defaulting to 1' do
      expect(Lapidary.config.analysis.poll_interval).to eq(1)
    end

    it 'has a cleanup_interval defaulting to 86400' do
      expect(Lapidary.config.analysis.cleanup_interval).to eq(86_400)
    end
  end

  describe 'redmine' do
    it 'has a url defaulting to bugs.ruby-lang.org' do
      expect(Lapidary.config.redmine.url).to eq('https://bugs.ruby-lang.org')
    end

    it 'has a timeout defaulting to 10' do
      expect(Lapidary.config.redmine.timeout).to eq(10)
    end
  end

  describe 'openai' do
    it 'has an api_key setting' do
      expect(Lapidary.config.openai).to respond_to(:api_key)
    end

    it 'has a model defaulting to gpt-5-mini' do
      expect(Lapidary.config.openai.model).to eq('gpt-5-mini')
    end
  end
end
