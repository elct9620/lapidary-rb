# frozen_string_literal: true

RSpec.describe 'Sentry configuration' do
  it 'sends default PII for AI monitoring messages' do
    expect(Sentry.configuration.send_default_pii).to be true
  end

  context 'when TRUSTED_PROXIES is configured' do
    it 'includes trusted proxies from config' do
      allow(Lapidary.config.proxy).to receive(:trusted).and_return(['172.64.0.0/13', '103.21.244.0/22'])

      # Re-run the sentry config to pick up the mocked proxies
      load Lapidary.root.join('config/sentry.rb').to_s

      expect(Sentry.configuration.trusted_proxies).to include('172.64.0.0/13', '103.21.244.0/22')
    end
  end
end
