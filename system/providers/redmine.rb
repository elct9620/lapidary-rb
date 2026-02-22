# frozen_string_literal: true

Lapidary::Container.register_provider(:redmine) do
  prepare do
    require 'redmine/api'
  end

  start do
    register('redmine_api', Redmine::API.new)
  end
end
