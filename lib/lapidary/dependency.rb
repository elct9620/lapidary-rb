# frozen_string_literal: true

require_relative 'container'

module Lapidary
  Dependency = Dry::AutoInject(Container)
end
