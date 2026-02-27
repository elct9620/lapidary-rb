# frozen_string_literal: true

Lapidary::Container.register_provider(:job_retention) do
  start do
    register('job_retention', ENV.fetch('JOB_RETENTION', nil))
  end
end
