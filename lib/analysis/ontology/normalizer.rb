# auto_register: false
# frozen_string_literal: true

module Analysis
  module Ontology
    # Resolves Rubyist names to canonical usernames using job context.
    class Normalizer
      def call(triplet, arguments)
        return triplet unless arguments

        normalized_subject = resolve_subject(triplet.subject, arguments)
        return triplet if normalized_subject.equal?(triplet.subject)

        triplet.with(subject: normalized_subject)
      end

      private

      def resolve_subject(subject, arguments)
        username = arguments.author_username
        display_name = arguments.author_display_name

        if matches_author?(subject.name, username, display_name)
          merge_display_name(subject.with(name: username || subject.name), display_name)
        else
          subject
        end
      end

      def matches_author?(name, username, display_name)
        downcased = name.downcase
        (username && downcased == username.downcase) ||
          (display_name && downcased == display_name.downcase)
      end

      def merge_display_name(subject, display_name)
        return subject unless display_name

        subject.with(properties: subject.properties.merge(display_name: display_name))
      end
    end
  end
end
