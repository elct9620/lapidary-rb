# auto_register: false
# frozen_string_literal: true

module Health
  # Health check endpoint
  class API < Lapidary::BaseController
    get '/' do
      respond_json(status: 'ok')
    end
  end
end
