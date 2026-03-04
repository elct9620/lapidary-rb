# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::Jobs::AnalysisJob do
  subject(:job) { Lapidary::Container['analysis.jobs.analysis_job'] }

  it 'is a BaseJob subclass' do
    expect(job).to be_a(Lapidary::Analysis::BaseJob)
  end

  it 'responds to #call' do
    expect(job).to respond_to(:call)
  end
end
