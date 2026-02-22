# frozen_string_literal: true

require_relative 'config/environment'

namespace :db do
  desc 'Run migrations'
  task :migrate, [:version] do |_t, args|
    Lapidary::Container.finalize!
    version = args[:version]&.to_i
    Lapidary::Container['migrator'].migrate(target: version)
  end
end
