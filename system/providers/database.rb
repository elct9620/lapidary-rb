# frozen_string_literal: true

Lapidary::Container.register_provider(:database) do
  prepare do
    require 'sequel'
  end

  start do
    env = Lapidary.config.env

    database_url = if env == 'test'
                     'sqlite:/'
                   else
                     "sqlite://data/#{env}.sqlite3"
                   end

    database = Sequel.connect(
      database_url,
      single_threaded: true,
      connect_sqls: ['PRAGMA busy_timeout=5000', 'PRAGMA journal_mode=WAL']
    )

    register('database', database)
  end

  stop do
    container['database'].disconnect
  end
end
