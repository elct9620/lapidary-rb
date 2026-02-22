# frozen_string_literal: true

require_relative 'config/environment'

namespace :db do
  desc 'Run migrations'
  task :migrate, [:version] do |_t, args|
    Lapidary::Container.finalize!
    db = Lapidary::Container['database']
    Sequel.extension :migration
    version = args[:version]&.to_i
    Sequel::Migrator.run(db, 'db/migrations', target: version)
  end
end
