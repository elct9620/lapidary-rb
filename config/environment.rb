# frozen_string_literal: true

require 'dotenv/load' if ENV.fetch('RACK_ENV', 'development') == 'development'

require_relative '../lib/lapidary/container'
require_relative 'web'
