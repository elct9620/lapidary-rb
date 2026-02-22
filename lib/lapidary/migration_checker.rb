# frozen_string_literal: true

module Lapidary
  # Checks if database migrations are current at startup.
  class MigrationChecker
    include Dependency['database', 'logger']

    def call
      Sequel.extension :migration
      migrations_path = Container.root.join('db', 'migrations').to_s

      return unless Dir.exist?(migrations_path)
      return if Dir.glob(File.join(migrations_path, '*.rb')).empty?

      return if Sequel::Migrator.is_current?(database, migrations_path)

      logger.warn(self, 'Database migrations are pending. Run: bundle exec rake db:migrate')
    rescue Sequel::Error => e
      logger.warn(self, 'Unable to check migration status', e)
    end
  end
end
