# frozen_string_literal: true

module Misc
  # API endpoints for miscellaneous routes
  class API < Lapidary::BaseController
    get '/' do
      'Hello World'
    end
  end
end
