# frozen_string_literal: true

require_relative '../lib/lapidary/base_controller'
require_relative '../apps/controllers/root_controller'

module Lapidary
  # The main Rack application composing all controllers
  class Web < Lapidary::BaseController
    use RootController

    def self.container
      Lapidary::Container
    end
  end
end
