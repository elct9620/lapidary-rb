# frozen_string_literal: true

require 'dry/system'
require_relative 'config'

# Lapidary is a Ruby web application that builds a knowledge graph from bugs.ruby-lang.org issue data.
module Lapidary
  def self.root
    @root ||= Pathname(__dir__).join('../..').realpath
  end

  def self.config
    Config.config
  end

  # The IoC container for auto-registering components
  class Container < Dry::System::Container
    use :zeitwerk

    configure do |config|
      config.root = Lapidary.root
      config.component_dirs.add 'lib' do |dir|
        dir.namespaces.add 'lapidary', key: nil
      end
      config.component_dirs.add 'apps'
    end

    after(:finalize) do
      self['migrator'].check
    end

    after(:finalize) do
      self['event_bus'].subscribe(self['analysis.subscribers.entity_discovered_subscriber'])
    end
  end
end
