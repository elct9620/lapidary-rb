# frozen_string_literal: true

require 'bundler'
Bundler.require(:default, ENV.fetch('RACK_ENV', 'development').to_sym)

Dotenv.load if defined?(Dotenv)

require_relative '../lib/lapidary/container'
require_relative 'web'
