# auto_register: false
# frozen_string_literal: true

require 'yaml'

module Analysis
  module Ontology
    # Stateless registry of valid CoreModule and Stdlib names from the curated ontology.
    module ModuleRegistry
      DATA_PATH = Lapidary.root.join('config', 'module_registry.yml').freeze
      private_constant :DATA_PATH

      data = YAML.load_file(DATA_PATH)

      CORE_MODULES = Set.new(data.fetch('core_modules')).freeze
      STDLIBS = Set.new(data.fetch('stdlibs')).freeze

      def self.core_module?(name)
        CORE_MODULES.include?(name)
      end

      def self.stdlib?(name)
        STDLIBS.include?(name)
      end

      def self.valid?(name)
        core_module?(name) || stdlib?(name)
      end

      def self.core_module_names
        CORE_MODULES.to_a.sort
      end

      def self.stdlib_names
        STDLIBS.to_a.sort
      end
    end
  end
end
