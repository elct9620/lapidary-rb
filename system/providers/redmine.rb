# frozen_string_literal: true

Lapidary::Container.register_provider(:redmine) do
  start do
    register('redmine_api', Redmine::API.new(base_url: ENV.fetch('REDMINE_URL', 'https://bugs.ruby-lang.org')))
  end
end
