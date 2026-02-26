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

    def check
      return unless migrations_available?
      return if Sequel::Migrator.is_current?(database, migrations_path)

      logger.warn(self, 'Database migrations are pending. Run: bundle exec rake db:migrate')
    rescue Sequel::Error => e
      logger.warn(self, "Unable to check migration status: #{e.message}")
    end

    def migrate(target: nil)
      return unless migrations_available?

      Sequel::Migrator.run(database, migrations_path, target: target)
    end

    private

    def migrations_path
      @migrations_path ||= Container.root.join('db', 'migrations').to_s
    end

    def migrations_available?
      Dir.exist?(migrations_path) && Dir.glob(File.join(migrations_path, '*.rb')).any?
    end
  end
end
