#!/usr/bin/env -S falcon host
# frozen_string_literal: true

require 'falcon/environment/rack'

hostname = File.basename(__dir__)

service hostname do
  include Falcon::Environment::Rack
end
