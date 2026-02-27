# frozen_string_literal: true

Lapidary::Container.register_provider(:redmine) do
  start do
    redmine_config = Lapidary.config.redmine
    register('redmine_api', Redmine::API.new(
                              base_url: redmine_config.url,
                              open_timeout: redmine_config.timeout,
                              read_timeout: redmine_config.timeout
                            ))
  end
end
