# frozen_string_literal: true

require 'sequel'
require 'sequel/extensions/migration'

module Lapidary
  # Manages database migration checking and execution.
  class Migrator
    include Dependency['database', 'logger']

    def initialize(migrations_path: nil, **deps)
      super(**deps)
      @migrations_path = migrations_path
    end

    def pending?
      return false unless migrations_available?

      !Sequel::Migrator.is_current?(database, migrations_path)
    rescue Sequel::Error
      false
    end

    def check
      return unless pending?

      logger.warn(self, 'Database migrations are pending. Run: bundle exec rake db:migrate')
    end

    def migrate(target: nil)
      return unless migrations_available?

      migrator = Sequel::TimestampMigrator.new(database, migrations_path, target: target)
      pending = pending_ups(migrator)

      if pending.empty?
        logger.info(self, 'Database is already up to date')
        return
      end

      pending.each { |_, filename, _| logger.info(self, "Applying #{File.basename(filename)}...") }
      migrator.run
      logger.info(self, "Applied #{pending.size} migration(s)")
    end

    private

    def migrations_path
      @migrations_path ||= Container.root.join('db', 'migrations').to_s
    end

    def pending_ups(migrator)
      migrator.migration_tuples.select { |_, _, direction| direction == :up }
    end

    def migrations_available?
      Dir.exist?(migrations_path) && Dir.glob(File.join(migrations_path, '*.rb')).any?
    end
  end
end
