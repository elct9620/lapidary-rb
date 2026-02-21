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

- `config/environment.rb` — Environment entry point, requires the container and web app
- `config/web.rb` — `Lapidary::Web < Lapidary::BaseController`, the main Rack app that composes all controllers via `use`, exposes `Web.container`
- `apps/<domain>/` — Domain-based modules, each subdirectory represents a domain (e.g., `apps/misc/`) containing its API controllers, models, etc.
- `config.ru` — Rack entry point, finalizes the container then runs `Lapidary::Web`
- `falcon.rb` — Falcon server configuration (async hosting via TCP, port from `PORT` env or 9292)
- `lib/lapidary/container.rb` — dry-system container with Zeitwerk plugin, auto-registers from `lib/lapidary/`, includes `apps/` (auto_register: false, Zeitwerk autoloaded)
- `lib/lapidary/dependency.rb` — `Lapidary::Dependency` mixin (`Dry::AutoInject`)
- `system/providers/` — dry-system provider directory (for registering external services like databases, caches)
- `docs/architecture.md` — Detailed architecture documentation

### Adding a Component

Place a class under `lib/lapidary/` and it auto-registers with the container. The `lapidary` namespace is stripped from the key:

- `lib/lapidary/greeter.rb` → resolves as `Container['greeter']`
- `lib/lapidary/services/foo.rb` → resolves as `Container['services.foo']`

Inject into other classes with `include Lapidary::Dependency['greeter']`.

### Adding a Domain Controller

Create a domain directory under `apps/` and add a controller — `api.rb` for JSON APIs or `web.rb` for HTML pages (both can coexist). Zeitwerk autoloads the constant — no `require_relative` needed:

```ruby
# apps/webhooks/api.rb
module Webhooks
  class API < Lapidary::BaseController
    post '/webhook' do
      'OK'
    end
  end
end
```

Mount it in `config/web.rb`:

```ruby
class Web < Lapidary::BaseController
  use Webhooks::API
end
```

`apps/` is registered in `container.rb` with `auto_register: false` and loaded via Zeitwerk autoloading (dry-system `:zeitwerk` plugin).

## Testing

- `spec_helper.rb` loads `lib/lapidary/container` — the container is available in all specs
- `rack-test` is available for HTTP integration tests
- RSpec runs in random order with `--format documentation`
- SimpleCov is configured with HTML + Cobertura formatters (output in `coverage/`)
- dry-system stubs are enabled via `Lapidary::Container.enable_stubs!` — use `Container.stub('key', mock)` in tests
- Integration tests should finalize the container in `before(:all) { Lapidary::Container.finalize! }`

## Conventions

- Ruby 3.4 target (`TargetRubyVersion` in `.rubocop.yml`)
- All Ruby files must include `# frozen_string_literal: true`
- RuboCop is configured with `NewCops: enable` — all new cops are opted in by default
- A PostToolUse hook automatically runs RuboCop with `--autocorrect` on any `.rb` file after edits
