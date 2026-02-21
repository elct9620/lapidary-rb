# frozen_string_literal: true

module Health
  # Health check endpoint
  class API < Lapidary::BaseController
    get '/' do
      content_type :json
      JSON.generate(status: 'ok')
    end
  end
end
