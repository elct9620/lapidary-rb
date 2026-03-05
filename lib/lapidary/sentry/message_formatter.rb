# auto_register: false
# frozen_string_literal: true

module Lapidary
  module Sentry
    # Formats RubyLLM message objects into Sentry-compatible data structures.
    module MessageFormatter
      private

      def format_messages(messages)
        JSON.generate(messages.map { |m| format_message(m) })
      end

      def format_message(message)
        msg = { role: message.role.to_s, parts: message_parts(message) }
        msg[:tool_call_id] = message.tool_call_id if message.tool_call_id
        msg
      end

      def message_parts(message)
        parts = []
        parts << { type: 'text', content: message.content.to_s } if message.content
        message.tool_calls&.each_value do |tc|
          parts << { type: 'tool_call', id: tc.id, name: tc.name, arguments: tc.arguments }
        end
        parts
      end
    end
  end
end
