# auto_register: false
# frozen_string_literal: true

module Lapidary
  module Console
    # Simple table formatter for console command output
    module TableFormatter
      private

      def print_table(headers, rows)
        return puts 'No results found.' if rows.empty?

        string_rows = rows.map { |row| row.map(&:to_s) }
        widths = calculate_widths(headers, string_rows)

        print_table_body(headers, string_rows, widths)
        puts "#{string_rows.size} row(s)"
      end

      def print_table_body(headers, rows, widths)
        puts format_row(headers, widths)
        puts widths.map { |w| '-' * w }.join(' | ')
        rows.each { |row| puts format_row(row, widths) }
      end

      def print_detail(pairs)
        label_width = pairs.map { |label, _| label.to_s.length }.max
        pairs.each do |label, value|
          puts "#{label.to_s.ljust(label_width)}  #{value}"
        end
      end

      def calculate_widths(headers, rows)
        headers.each_with_index.map do |header, i|
          [header.length, *rows.map { |row| row[i]&.length || 0 }].max
        end
      end

      def format_row(values, widths)
        values.each_with_index.map { |v, i| v.to_s.ljust(widths[i]) }.join(' | ')
      end
    end
  end
end
