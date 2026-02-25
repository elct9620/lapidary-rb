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
bundle exec rake 'db:generate[create_foo]'  # Generate a new migration file with timestamp
docker build -t lapidary .  # Build container image
docker run -p 9292:9292 lapidary  # Run container
```

## Architecture

The application uses dry-system as an IoC container. Components are auto-registered and can be resolved from the container or injected via `Lapidary::Dependency`.

- `config.ru` — Rack entry point, finalizes the container then runs `Lapidary::Web`
- `config/environment.rb` — Environment entry point, requires the container and web app
- `config/web.rb` — `Lapidary::Web < Lapidary::BaseController`, the main Rack app that composes all domain controllers via `use`
- `lib/lapidary/container.rb` — dry-system container with Zeitwerk plugin, auto-registers from both `lib/lapidary/` and `apps/`
- `lib/lapidary/dependency.rb` — `Lapidary::Dependency` mixin (`Dry::AutoInject`)
- `lib/lapidary/base_controller.rb` — `Sinatra::Base` subclass, base for all controllers
- `lib/<domain>/` — Domain inner-layer components (entities, use cases) organized by bounded context
- `apps/<domain>/` — Domain outer-layer components (controllers, contracts, repositories, adapters, subscribers) organized by bounded context

**Bounded Contexts**: `webhooks` (webhook reception + Redmine API fetching), `analysis` (job processing + LLM extraction pipeline), `graph` (knowledge graph query API), `health` (liveness probe)
- `system/providers/` — dry-system provider directory (for registering external services like databases, caches)
- `falcon.rb` — Defines two Falcon services: HTTP server (Rack app) and `analysis` background worker (async polling service)
- `docs/architecture.md` — Detailed architecture documentation
- `SPEC.md` — Behavioral specification

### Dependency Injection Boundaries

This project follows the Clean Architecture dependency rule: inner layers (Entity, Use Case) must never depend on outer layers (Framework, Infrastructure). Since `Lapidary::Dependency` (`Dry::AutoInject`) is framework infrastructure, only outer-layer components may use it. Inner-layer components receive dependencies through plain Ruby constructor injection, and outer layers are responsible for assembly — keeping the dependency direction always pointing inward. Marking `# auto_register: false` is a consequence of this rule, as inner-layer components are not managed by the container.

| Layer | Location | Uses `Lapidary::Dependency`? | `auto_register: false`? | Example |
|---|---|---|---|---|
| Controller (adapter) | `apps/` | **No** — uses `container[]` for lazy resolution | Yes — mounted via `use`, not resolved | `Webhooks::API` |
| Adapter (outer) | `apps/` | Yes — publishes domain events | No — auto-registered | `Webhooks::Adapters::AnalysisScheduler` |
| Subscriber (outer) | `apps/` | Yes — reacts to domain events | No — auto-registered | `Analysis::Subscribers::EntityDiscoveredSubscriber` |
| Repository (adapter) | `apps/` | Yes — bridges domain and infrastructure | No — auto-registered | `Webhooks::Repositories::AnalysisRecordRepository` |
| Contract (adapter) | `apps/` | N/A | No — auto-registered | `Webhooks::Contract` |
| Use Case (domain) | `lib/` | **No** — inner layer must not depend on framework | Yes — not container-managed | `Webhooks::UseCases::HandleWebhook` |
| Entity (domain) | `lib/` | **No** — inner layer must not depend on framework | Yes — domain object | `Webhooks::Entities::AnalysisRecord` |

Controllers (outer layer) resolve dependencies from the container and assemble Use Cases (inner layer):

```ruby
# Controller (adapter) resolves from container and wires into Use Case (domain)
use_case = UseCases::HandleWebhook.new(analysis_record_repository: container['webhooks.repositories.analysis_record_repository'])
output = use_case.call(issue_id)
```

### Value Object Convention

Immutable value objects use Ruby's `Data.define` with a consistent enum-like pattern for domain constants:

```ruby
# Enum-like value object with constants
Direction = Data.define(:value) do
  def to_s = value
end

class Direction
  OUTBOUND = new(value: 'outbound')
  INBOUND = new(value: 'inbound')
  BOTH = new(value: 'both')
end
```

This pattern is used throughout: `EntityType`, `JobStatus`, `NodeType`, `RelationshipType`, `Direction`. Data value objects with optional fields use constructor defaults and type coercions (e.g., `String()`, `Integer()`).

Other `Data.define` value objects: `Triplet`, `Node`, `Edge`, `Neighbor`, `Author`, `JobArguments`.

### Cross-Context Entity Strategy

Each bounded context owns its own entity models. Structural similarity between entities across BCs (e.g., `Webhooks::Entities::AnalysisRecord` and `Analysis::Entities::AnalysisRecord`) is **intentional by design**, not accidental duplication. Each entity reflects only the behavior its BC needs. See `docs/architecture.md` § "Cross-Context Entity Strategy" for details.

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

### Analysis Pipeline

The `Analysis::Service` (background worker via Falcon) polls the job queue and runs `ProcessJob`, which orchestrates a four-stage pipeline:

1. **Extraction** — `LlmExtractor` sends job content to OpenAI via `ruby_llm` gem with structured output schema → candidate `Triplet` objects
2. **Validation** — `Analysis::Ontology::Validator` checks ontology constraints; downgrades `Maintenance` → `Contribute` for non-committers; rejects invalid triplets
3. **Normalization** — `Analysis::Ontology::Normalizer` resolves extracted Rubyist names to canonical usernames using job's author context
4. **Graph Writing** — `GraphRepository` upserts Nodes and Edges, appending observation records; deduplicates by `(source_entity_type, source_entity_id)`

The ontology subdomain (`lib/analysis/ontology/`) contains stateless domain objects: `Validator`, `Normalizer`, and `ModuleRegistry` (curated list of core modules and stdlibs).

Node IDs use URI format: `type://name` (e.g., `rubyist://matz`, `core_module://Array`). Built via `Lapidary::NodeId.build(type, name)`.

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
- `apps/webhooks/repositories/analysis_record_repository.rb` → resolves as `Container['webhooks.repositories.analysis_record_repository']`

Inner-layer (domain) Use Cases and Entities live under `lib/<domain>/` (e.g., `lib/webhooks/entities/`, `lib/webhooks/use_cases/`). They are marked `# auto_register: false` to exclude them from container management. Zeitwerk autoloads them via the `lib/` root directory (e.g., `lib/webhooks/entities/issue.rb` → `Webhooks::Entities::Issue`).

#### Cross-Context Communication via Events

Bounded contexts communicate through domain events via a `dry-events` event bus (`Container['event_bus']`). The publishing context publishes events without knowing about subscribers. Subscribing contexts register listeners that react independently.

- **Adapter** publishes events: `apps/webhooks/adapters/analysis_scheduler.rb` publishes `webhooks.entity_discovered`
- **Subscriber** reacts to events: `apps/analysis/subscribers/entity_discovered_subscriber.rb` enqueues analysis jobs

Event subscription wiring happens in `Container.after(:finalize)` in `lib/lapidary/container.rb`.

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

Inject dependencies into other outer-layer classes (e.g., repositories) with `include Lapidary::Dependency['webhooks.contract']`. Controllers resolve from the container directly via `container['key']` instead.

### Repository DSL

Repositories use `Lapidary::RepositorySupport` for declarative boilerplate:

```ruby
class JobRepository
  include Lapidary::Dependency['database']
  include Lapidary::RepositorySupport

  table :jobs                      # defines private `dataset` method → database[:jobs]
  wraps_errors Entities::JobError  # defines private `with_error_wrapping` that rescues Sequel::Error

  def enqueue(job)
    with_error_wrapping { dataset.insert(...) }
  end
end
```

### Error Handling

Errors propagate naturally through the layers and are caught at the boundary:

- **Repository layer**: Wraps `Sequel::Error` as domain-specific errors (e.g., `AnalysisTrackingError`) via `RepositorySupport#wraps_errors` so inner layers don't depend on database details
- **Use Case layer**: Propagates domain errors — never swallows them
- **Controller layer**: Handles domain-specific errors with appropriate HTTP status codes; unhandled exceptions are caught by `BaseController`'s global `error` handler which logs the full error and returns a safe `500` JSON response (no internal details leaked)

## Database

- **Providers**: `database.rb` → `Container['database']` (Sequel), `logger.rb` → `Container['logger']` (Console), `redmine.rb` → `Container['redmine_api']` (Redmine::API), `event_bus.rb` → `Container['event_bus']` (dry-events publisher), `llm.rb` → `Container['llm']` (RubyLLM/OpenAI)
- **Test**: in-memory SQLite (`sqlite:/`) — no file on disk, fast and isolated
- **Development/Production**: file-based SQLite (`data/<env>.sqlite3`) with WAL journal mode
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
| `REDMINE_URL` | `https://bugs.ruby-lang.org` | Base URL for the Redmine JSON API |
| `OPENAI_API_KEY` | `nil` | OpenAI API key for LLM extraction pipeline |
| `OPENAI_MODEL` | `gpt-5-mini` | OpenAI model for triplet extraction |
| `WEBHOOK_SECRET` | `nil` | When set, webhook requests must include `?token=<value>` matching this secret |
