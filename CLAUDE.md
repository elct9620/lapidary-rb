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
bundle exec rake db:migrate # Run database migrations
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

### Dependency Injection Boundaries

This project follows the Clean Architecture dependency rule: inner layers (Entity, Use Case) must never depend on outer layers (Framework, Infrastructure). Since `Lapidary::Dependency` (`Dry::AutoInject`) is framework infrastructure, only outer-layer components may use it. Inner-layer components receive dependencies through plain Ruby constructor injection, and outer layers are responsible for assembly — keeping the dependency direction always pointing inward. Marking `# auto_register: false` is a consequence of this rule, as inner-layer components are not managed by the container.

| Layer | Uses `Lapidary::Dependency`? | `auto_register: false`? | Example |
|---|---|---|---|
| Controller (adapter) | **No** — uses `container[]` for lazy resolution | Yes — mounted via `use`, not resolved | `Webhooks::API` |
| Use Case (domain) | **No** — inner layer must not depend on framework | Yes — assembled by controller | `Webhooks::HandleWebhook` |
| Entity (domain) | **No** — inner layer must not depend on framework | Yes — domain object | `Webhooks::AnalysisRecord` |
| Repository (adapter) | Yes — outer layer, bridges domain and infrastructure | No — auto-registered | `Webhooks::AnalysisRecordRepository` |
| Contract (adapter) | N/A | No — auto-registered | `Webhooks::Contract` |

Controllers (outer layer) resolve dependencies from the container and assemble Use Cases (inner layer):

```ruby
# Controller (adapter) resolves from container and wires into Use Case (domain)
use_case = HandleWebhook.new(analysis_record_repository: container['webhooks.analysis_record_repository'])
output = use_case.call(issue_id)
```

### Entity-Centric Use Case Pattern

Use Cases operate through Entities, not raw data. The flow is: build Entity → query Repository with Entity → Entity mutates itself → Repository persists Entity. Repositories accept Entity objects, not keyword arguments.

```ruby
# Use Case builds Entity, delegates behavior to it
record = AnalysisRecord.new(entity_type: 'issue', entity_id: issue_id)
unless repository.exists?(record)
  record.analyze          # Entity marks itself as analyzed
  repository.save(record) # Repository accepts the Entity
end
```

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

Outer-layer (adapter) classes under `apps/` auto-register with the container by default. The directory name becomes the namespace:

- `apps/webhooks/contract.rb` → resolves as `Container['webhooks.contract']`
- `apps/webhooks/analysis_record_repository.rb` → resolves as `Container['webhooks.analysis_record_repository']`

Inner-layer (domain) Use Cases and Entities must not depend on framework infrastructure, so they are marked `# auto_register: false` to exclude them from container management.

Use `dry-validation` contracts for request validation (schema + rules):

```ruby
# apps/webhooks/contract.rb
module Webhooks
  class Contract < Dry::Validation::Contract
    json do
      required(:issue_id).filled(:integer)
    end

    rule(:issue_id) do
      key.failure('must be positive') unless value.positive?
    end
  end
end
```

Inject domain components into controllers: `include Lapidary::Dependency['webhooks.contract']`

## Database

- **Provider**: `system/providers/database.rb` registers a `Sequel::Database` instance as `Container['database']`
- **Test**: in-memory SQLite (`sqlite:/`) — no file on disk, fast and isolated
- **Development/Production**: file-based SQLite (`db/<env>.sqlite3`) with WAL journal mode
- **Migrations**: Sequel migrations in `db/migrations/`, named `YYYYMMDDHHMMSS_description.rb`

## Testing

- `spec_helper.rb` loads `lib/lapidary/container` — the container is available in all specs
- Container is finalized once in `before(:suite)`, migrations run automatically
- Each test runs inside `db.transaction(rollback: :always)` for isolation
- `rack-test` is available for HTTP integration tests
- RSpec runs in random order with `--format documentation`
- SimpleCov is configured with HTML + Cobertura formatters (output in `coverage/`)
- dry-system stubs are enabled via `Lapidary::Container.enable_stubs!` — use `Container.stub('key', mock)` in tests

## Conventions

- Ruby 3.4 target (`TargetRubyVersion` in `.rubocop.yml`)
- All Ruby files must include `# frozen_string_literal: true`
- RuboCop is configured with `NewCops: enable` — all new cops are opted in by default
- A PostToolUse hook automatically runs RuboCop with `--autocorrect` on any `.rb` file after edits

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `RACK_ENV` | `development` | Affects database path and Sinatra environment |
| `PORT` | `9292` | HTTP listen port (Falcon only, configured in `falcon.rb`) |
