# frozen_string_literal: true

require_relative '../../lib/lapidary/base_controller'

# Handles the root route
class RootController < Lapidary::BaseController
  get '/' do
    'Hello World'
  end
end
