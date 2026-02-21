# frozen_string_literal: true

require_relative 'config/environment'

Lapidary::Container.finalize!
run Lapidary::Web
