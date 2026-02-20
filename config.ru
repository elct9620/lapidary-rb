# frozen_string_literal: true

require_relative 'app'

Lapidary::Container.finalize!
run App
