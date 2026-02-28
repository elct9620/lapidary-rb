# frozen_string_literal: true

Lapidary::Container.register_provider(:logger) do
  start do
    register('logger', Console.logger)
  end
end
