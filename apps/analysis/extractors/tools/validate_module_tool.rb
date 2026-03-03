# auto_register: false
# frozen_string_literal: true

module Analysis
  module Extractors
    module Tools
      # Validates whether a module name exists in the curated module lists.
      # Returns the canonical name if found, or suggests similar names if not.
      class ValidateModuleTool < RubyLLM::Tool
        description 'Validate whether a module name exists in the curated module lists. ' \
                    'Returns the canonical name if found, or suggests similar names if not.'

        param :name, desc: 'Module name to validate (case-sensitive)'

        def execute(name:)
          if Ontology::ModuleRegistry.valid?(name)
            { valid: true, name: name }.to_json
          else
            { valid: false, name: name, suggestions: find_similar(name) }.to_json
          end
        end

        private

        def find_similar(name)
          all_names = Ontology::ModuleRegistry.core_module_names +
                      Ontology::ModuleRegistry.stdlib_names
          downcased = name.downcase
          all_names.select { |n| n.downcase.include?(downcased) || downcased.include?(n.downcase) }
                   .first(5)
        end
      end
    end
  end
end
