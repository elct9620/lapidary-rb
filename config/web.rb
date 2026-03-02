# frozen_string_literal: true

module Lapidary
  # The main Rack application composing all controllers
  class Web < Lapidary::BaseController
    set :public_folder, File.expand_path('../public', __dir__)

    use Health::API
    use Webhooks::API
    use Graph::API

    get '/' do
      send_file File.join(settings.public_folder, 'index.html')
    end
  end
end
