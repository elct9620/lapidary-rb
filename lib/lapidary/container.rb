# frozen_string_literal: true

require 'dry/system'

module Lapidary
  # The IoC container for auto-registering components
  class Container < Dry::System::Container
    configure do |config|
      config.root = Pathname(__dir__).join('../..').realpath
      config.component_dirs.add 'lib' do |dir|
        dir.namespaces.add 'lapidary', key: nil
      end
    end
  end
end
