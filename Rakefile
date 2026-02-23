# frozen_string_literal: true

require_relative 'config/environment'

namespace :db do
  desc 'Run migrations'
  task :migrate, [:version] do |_t, args|
    Lapidary::Container.finalize!
    version = args[:version]&.to_i
    Lapidary::Container['migrator'].migrate(target: version)
  end

  desc 'Generate a new migration file'
  task :generate, [:name] do |_t, args|
    abort 'Usage: rake db:generate[migration_name]' unless args[:name]

    timestamp = Time.now.strftime('%Y%m%d%H%M%S')
    filename = "db/migrations/#{timestamp}_#{args[:name]}.rb"
    content = <<~RUBY
      # frozen_string_literal: true

      Sequel.migration do
        change do
        end
      end
    RUBY

    File.write(filename, content)
    puts "Created #{filename}"
  end
end
