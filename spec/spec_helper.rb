# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start do
  add_filter '/spec/'

  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CoberturaFormatter
    ]
  )
end

require_relative '../lib/lapidary/container'

require 'dry/system/stubs'

Lapidary::Container.enable_stubs!

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed

  config.before(:suite) do
    require 'console'
    Lapidary::Container.stub('logger', Console::Logger.new(Console::Output::Null.new))
    Lapidary::Container.finalize!
    Lapidary::Container['migrator'].migrate
  end

  config.around(:each) do |example|
    db = Lapidary::Container['database']
    db.transaction(rollback: :always, auto_savepoint: true) do
      example.run
    end
  end
end
