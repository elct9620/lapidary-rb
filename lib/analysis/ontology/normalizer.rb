# auto_register: false
# frozen_string_literal: true

module Analysis
  module Ontology
    # Resolves Rubyist names to canonical usernames using job context.
    class Normalizer
      def call(triplet, arguments)
        normalized_name = resolve_subject_name(triplet.subject.name, arguments)
        return triplet if normalized_name == triplet.subject.name

        triplet.with(subject: triplet.subject.with(name: normalized_name))
      end

      private

      def resolve_subject_name(name, arguments)
        return name unless arguments

        username = arguments.author_username
        display_name = arguments.author_display_name

        if username && name.downcase == username.downcase
          username
        elsif display_name && name.downcase == display_name.downcase
          username || name
        else
          name
        end
      end
    end
  end
end
