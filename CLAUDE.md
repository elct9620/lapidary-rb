# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lapidary is a Ruby web application built with **Sinatra** (Rack-based DSL), served by **Falcon** (async HTTP server), and using **dry-system** for dependency injection and component management.

## Commands

```bash
bundle install              # Install dependencies
falcon host                 # Run the server (via Falcon, binds to TCP 0.0.0.0:9292)
bundle exec rackup          # Run the server (via Rack, localhost:9292)
bundle exec rspec           # Run all tests
bundle exec rspec spec/lapidary/container_spec.rb  # Run a single test file
bundle exec rubocop         # Lint
bundle exec rubocop --autocorrect  # Lint with auto-fix
```

## Architecture

The application uses dry-system as an IoC container. Components placed under `lib/lapidary/` are auto-registered and can be resolved from the container or injected via `Lapidary::Dependency`.

- `app.rb` — Sinatra application (`App < Sinatra::Base`), exposes `App.container`
- `config.ru` — Rack entry point, finalizes the container then runs `App`
- `falcon.rb` — Falcon server configuration (async hosting via TCP, port from `PORT` env or 9292)
- `lib/lapidary/container.rb` — dry-system container, auto-registers from `lib/lapidary/`
- `lib/lapidary/dependency.rb` — `Lapidary::Dependency` mixin (`Dry::AutoInject`)
- `system/providers/` — External service providers (database, cache, etc.)

### Adding a Component

Place a class under `lib/lapidary/` and it auto-registers with the container. The `lapidary` namespace is stripped from the key:

- `lib/lapidary/greeter.rb` → resolves as `Container['greeter']`
- `lib/lapidary/services/foo.rb` → resolves as `Container['services.foo']`

Inject into other classes with `include Lapidary::Dependency['greeter']`.

## Testing

- `spec_helper.rb` loads `lib/lapidary/container` — the container is available in all specs
- `rack-test` is available for HTTP integration tests
- RSpec runs in random order with `--format documentation`

## Conventions

- Ruby 3.4 target (`TargetRubyVersion` in `.rubocop.yml`)
- All Ruby files must include `# frozen_string_literal: true`
- RuboCop is configured with `NewCops: enable` — all new cops are opted in by default
- A PostToolUse hook automatically runs RuboCop with `--autocorrect` on any `.rb` file after edits
