# frozen_string_literal: true

require 'dry/system'

module Lapidary
  # The IoC container for auto-registering components
  class Container < Dry::System::Container
    use :zeitwerk

    configure do |config|
      config.root = Pathname(__dir__).join('../..').realpath
      config.component_dirs.add 'lib' do |dir|
        dir.namespaces.add 'lapidary', key: nil
      end
      config.component_dirs.add 'apps'
    end

    after(:finalize) do
      self['migrator'].check
      self['event_bus'].subscribe(self['analysis.subscribers.entity_discovered_subscriber'])
    end
  end
end
