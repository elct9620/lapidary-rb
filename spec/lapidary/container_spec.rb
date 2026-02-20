# frozen_string_literal: true

RSpec.describe Lapidary::Container do
  it 'can be finalized' do
    expect { described_class.finalize! }.not_to raise_error
  end
end
