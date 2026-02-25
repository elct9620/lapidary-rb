# frozen_string_literal: true

module Lapidary
  # The main Rack application composing all controllers
  class Web < Lapidary::BaseController
    use Health::API
    use Webhooks::API
    use Graph::API
  end
end
