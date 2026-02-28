# frozen_string_literal: true

Lapidary::Container.register_provider(:database) do
  start do
    env = Lapidary.config.env

    database_url = if env == 'test'
                     'sqlite:/'
                   else
                     "sqlite://data/#{env}.sqlite3"
                   end

    options = {
      single_threaded: true,
      connect_sqls: ['PRAGMA busy_timeout=5000', 'PRAGMA journal_mode=WAL']
    }

    # Non-test: sharded pool with a read-only connection so SELECTs don't
    # contend with the Analysis worker's write lock.
    # In-memory SQLite (test) can't share data between connections.
    options[:servers] = { read_only: { readonly: true } } unless env == 'test'

    database = Sequel.connect(database_url, **options)

    register('database', database)
  end

  stop do
    container['database'].disconnect
  end
end
