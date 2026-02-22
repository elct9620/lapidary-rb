# frozen_string_literal: true

Lapidary::Container.register_provider(:redmine) do
  start do
    register('redmine_api', Redmine::API.new)
  end
end
