# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'logger provider' do
  subject(:logger) { Lapidary::Container['logger'] }

  it 'resolves a Console logger' do
    expect(logger).to be_a(Console::Logger)
  end
end
