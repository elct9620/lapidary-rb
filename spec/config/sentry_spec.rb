# frozen_string_literal: true

RSpec.describe 'Sentry configuration' do
  it 'sends default PII for AI monitoring messages' do
    expect(Sentry.configuration.send_default_pii).to be true
  end
end
