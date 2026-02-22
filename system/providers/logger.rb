# frozen_string_literal: true

Lapidary::Container.register_provider(:logger) do
  prepare do
    require 'console'
  end

  start do
    register('logger', Console.logger)
  end
end
