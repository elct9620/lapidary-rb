# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lapidary is a Ruby web application that builds a knowledge graph from bugs.ruby-lang.org issue data. It receives webhook notifications, fetches issue details from the Redmine JSON API, and stores structured data in SQLite. Built with **Sinatra** (Rack-based DSL), served by **Falcon** (async HTTP server), and using **dry-system** for dependency injection and component management.

## Commands

```bash
bundle install              # Install dependencies
falcon host                 # Run the server (via Falcon, binds to TCP 0.0.0.0:9292)
bundle exec rackup          # Run the server (via Rack, localhost:9292)
bundle exec rspec           # Run all tests
bundle exec rspec spec/apps/webhooks/api_spec.rb  # Run a single test file
bundle exec rubocop         # Lint
bundle exec rubocop --autocorrect  # Lint with auto-fix
```

## Architecture

The application uses dry-system as an IoC container. Components are auto-registered and can be resolved from the container or injected via `Lapidary::Dependency`.

- `config.ru` — Rack entry point, finalizes the container then runs `Lapidary::Web`
- `config/environment.rb` — Environment entry point, requires the container and web app
- `config/web.rb` — `Lapidary::Web < Lapidary::BaseController`, the main Rack app that composes all domain controllers via `use`
- `lib/lapidary/container.rb` — dry-system container with Zeitwerk plugin, auto-registers from both `lib/lapidary/` and `apps/`
- `lib/lapidary/dependency.rb` — `Lapidary::Dependency` mixin (`Dry::AutoInject`)
- `lib/lapidary/base_controller.rb` — `Sinatra::Base` subclass, base for all controllers
- `apps/<domain>/` — Domain-based modules (e.g., `apps/webhooks/`), each containing controllers, contracts, use cases
- `system/providers/` — dry-system provider directory (for registering external services like databases, caches)
- `docs/architecture.md` — Detailed architecture documentation
- `SPEC.md` — Behavioral specification for V1

### Adding a Component

Place a class under `lib/lapidary/` and it auto-registers with the container. The `lapidary` namespace is stripped from the key:

- `lib/lapidary/greeter.rb` → resolves as `Container['greeter']`
- `lib/lapidary/services/foo.rb` → resolves as `Container['services.foo']`

Inject into other classes with `include Lapidary::Dependency['greeter']`.

### Adding a Domain Controller

Create a domain directory under `apps/` and add a controller. Controllers must include the `# auto_register: false` magic comment to prevent dry-system registration (they are mounted as Rack middleware, not resolved from the container):

```ruby
# apps/webhooks/api.rb
# auto_register: false
# frozen_string_literal: true

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

### Adding Domain Components

Non-controller classes under `apps/` auto-register with the container. The directory name becomes the namespace:

- `apps/webhooks/contract.rb` → resolves as `Container['webhooks.contract']`
- `apps/webhooks/handle_webhook.rb` → resolves as `Container['webhooks.handle_webhook']`

Use `dry-validation` contracts for request validation:

```ruby
# apps/webhooks/contract.rb
module Webhooks
  class Contract < Dry::Validation::Contract
    json do
      required(:issue_id).filled(:integer)
    end
  end
end
```

Inject domain components into controllers: `include Lapidary::Dependency['webhooks.contract']`

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
