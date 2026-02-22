# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Redmine provider' do
  it 'registers redmine_api in the container' do
    expect(Lapidary::Container['redmine_api']).to be_a(Redmine::API)
  end
end
