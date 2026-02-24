# Architecture

## Overview

Lapidary is built on **Sinatra** (Rack-based web DSL), served by **Falcon** (async HTTP server), and uses **dry-system** for dependency injection. Data is stored in **SQLite** via **Sequel**.

For project goals, behavior specifications, and technical decisions, see [SPEC.md](../SPEC.md).

## System Layers

```
┌─────────────────────────────────┐
│  Adapters (apps/)               │  Controllers, repositories, contracts, adapters
├─────────────────────────────────┤
│  Domain (lib/<domain>/)         │  Entities, use cases (per bounded context)
├─────────────────────────────────┤
│  Infrastructure (lib/lapidary/) │  Auto-registered shared components
├─────────────────────────────────┤
│  Providers (system/providers/)  │  External services (database, HTTP client)
└─────────────────────────────────┘
```

### Domain Layer

`lib/<domain>/` (e.g., `lib/analysis/`, `lib/webhooks/`) contains inner-layer domain components — entities and use cases — organized by bounded context. These are Zeitwerk autoloaded via the `lib/` root directory (e.g., `lib/webhooks/entities/issue.rb` → `Webhooks::Entities::Issue`). Inner-layer files are marked `# auto_register: false` to exclude them from dry-system container registration. They receive dependencies through plain Ruby constructor injection.

### Adapter Layer

`apps/` contains outer-layer adapter components organized by domain. Each subdirectory represents a bounded context (e.g., `apps/webhooks/`) and contains that context's controllers, repositories, contracts, and cross-context adapters. The directory is registered as a `component_dirs` entry in the dry-system container and autoloaded via Zeitwerk (dry-system `:zeitwerk` plugin) — no manual `require` is needed. Components auto-register by default; controllers use the `# auto_register: false` magic comment to opt out (they are mounted as Rack middleware).

`config/web.rb` defines `Lapidary::Web`, the main Rack application that composes all API controllers via Sinatra's `use` middleware mechanism. Each API class inherits from `Lapidary::BaseController` and handles specific routes. `Lapidary::Web` exposes `Web.container` for accessing the DI container.

### Context Integration

Bounded contexts communicate through domain events via an **event bus** (`dry-events`). The publishing context knows nothing about subscribers — it simply publishes events. Subscribing contexts register listeners that react to events independently.

For example, `Webhooks::Adapters::AnalysisScheduler` publishes a `webhooks.entity_discovered` event when a new entity is found. `Analysis::Subscribers::EntityDiscoveredSubscriber` subscribes to this event and enqueues an analysis job. The Webhooks BC has zero dependency on Analysis internals.

The event bus is registered as a provider (`system/providers/event_bus.rb`). Subscription wiring happens in `Container.after(:finalize)` to ensure all components are registered before subscribers are connected.

Adapters live under `apps/<domain>/adapters/` and subscribers live under `apps/<domain>/subscribers/`. Both are auto-registered with the container.

### Cross-Context Entity Strategy

Each bounded context owns its own entity models, even when two contexts reference the same real-world concept. Structural similarity across BCs is **expected and intentional** — it is not accidental duplication.

Entities should reflect their BC's actual usage:

- **Analysis `AnalysisRecord`** — full lifecycle entity. Created, mutated via `analyze` (sets `analyzed_at`), queried with `analyzed?`, and persisted. Owns the analysis state machine.
- **Webhooks `AnalysisRecord`** — query-oriented value object. Created with `entity_type`/`entity_id`, passed to `exists?`/`untracked` for filtering. Never mutated — `analyzed_at` is accepted as a read-only constructor parameter for repository persistence only.

This separation ensures each BC depends only on the behavior it needs, and can evolve its entity independently without affecting the other context.

### Infrastructure Layer

Components under `lib/lapidary/` are auto-registered by dry-system. This layer contains shared infrastructure such as fetching issue data and persisting records. Components are resolved by container key with the `lapidary` namespace stripped (e.g., `lib/lapidary/services/foo.rb` → `Container['services.foo']`).

### Providers

`system/providers/` hosts dry-system providers that register external services (database connections, HTTP clients) into the container. These are resolved at container finalization time.

### Layer Convention

Each bounded context spans two directories:

- `lib/<domain>/` — Inner-layer (entities, use cases)
- `apps/<domain>/` — Outer-layer (controllers, repositories, contracts, adapters)

Domain directories:

- `analysis` — Job processing and analysis tracking
- `webhooks` — Webhook processing (issue notifications)
- `health` — Health check endpoint (outer layer only)

| Component | Location | `auto_register: false`? | Uses `Lapidary::Dependency`? | Description |
|---|---|---|---|---|
| Controller | `apps/` | Yes — mounted via `use`, not resolved | No — uses `container[]` | Sinatra controller handling HTTP routes |
| Adapter | `apps/` | No — auto-registered | Yes | Anti-Corruption Layer, publishes domain events |
| Subscriber | `apps/` | No — auto-registered | Yes | Reacts to domain events from other contexts |
| Repository | `apps/` | No — auto-registered | Yes | Data access, bridges domain and infrastructure |
| Contract | `apps/` | No — auto-registered | N/A | Request validation via `dry-validation` |
| Use Case | `lib/` | Yes — not container-managed | **No** — plain constructor injection | Business logic orchestration |
| Entity | `lib/` | Yes — domain object | **No** — no DI | Domain value/data objects |

**Dependency direction rule:** Inner layers (Entity, Use Case) must never depend on outer layers (Framework, Infrastructure). Only outer-layer components (Controller, Repository, Adapter) may use `Lapidary::Dependency` (`Dry::AutoInject`). Inner-layer components receive dependencies through plain Ruby constructor injection, keeping the dependency direction always pointing inward.

Controllers (outer layer) resolve dependencies from the container and assemble Use Cases (inner layer):

```ruby
# Controller wires dependencies into Use Case
use_case = UseCases::HandleWebhook.new(analysis_record_repository: analysis_record_repository)
output = use_case.call(issue_id)
```

Zeitwerk autoloads all constants under both `lib/` and `apps/` — no manual `require` is needed. The directory structure maps to Ruby module namespaces (e.g., `apps/webhooks/api.rb` → `Webhooks::API`, `lib/webhooks/entities/issue.rb` → `Webhooks::Entities::Issue`).

## Data Flow

```
Webhook (POST /webhook)
  │
  ▼
Validate request (JSON, issue_id)
  │
  ▼
Fetch issue from Redmine API
  GET /issues/{id}.json?include=journals
  │
  ▼
Determine untracked entities (Issue + Journals)
  │
  ▼
Publish 'webhooks.entity_discovered' events (one per untracked entity)
  │
  ▼
Analysis subscriber enqueues jobs (via event bus)
  │
  ▼
Respond 202 (accepted)

Analysis Service (background worker)
  │
  ▼
Dequeue job
  │
  ▼
Write analysis tracking record
  │
  ▼
Mark job as done
```

## Directory Structure

```
lib/
  lapidary/              # Infrastructure (Lapidary:: namespace, auto-registered)
    container.rb
    dependency.rb
    base_controller.rb
    migrator.rb
    analysis/
      environment.rb     # Framework & Driver (Falcon)
      service.rb         # Framework & Driver (background worker)
  analysis/              # Analysis BC inner layer (Analysis:: namespace)
    entities/
      analysis_record.rb
      analysis_tracking_error.rb
      job.rb
      job_error.rb
    use_cases/
      process_job.rb
  webhooks/              # Webhooks BC inner layer (Webhooks:: namespace)
    entities/
      analysis_record.rb
      analysis_tracking_error.rb
      issue.rb
      journal.rb
    use_cases/
      handle_webhook.rb
  redmine/
    api.rb               # External API integration
apps/                    # Outer layer only (adapters, controllers, contracts, subscribers)
  analysis/
    repositories/
      analysis_record_repository.rb
      job_repository.rb
    subscribers/
      entity_discovered_subscriber.rb  # Subscribes to webhooks.entity_discovered events
  webhooks/
    api.rb               # Controller
    contract.rb          # Contract
    adapters/
      analysis_scheduler.rb  # Publishes entity_discovered events via event bus
    repositories/
      analysis_record_repository.rb
      issue_repository.rb
  health/
    api.rb               # Controller
config/
  environment.rb         # Environment loader (container + web app)
  web.rb                 # Lapidary::Web — main Rack app, composes controllers
system/providers/        # External service providers (database, HTTP client, etc.)
config.ru                # Rack entry point
falcon.rb                # Falcon server configuration
```

## Dependency Injection

- `Lapidary::Container` — the central IoC container; auto-registers components under `lib/lapidary/`
- `Lapidary::Dependency` — mixin for injecting dependencies into classes via `include Dependency[...]`

## Adding a Component

Place a file under `lib/lapidary/` and it will be auto-registered:

```ruby
# lib/lapidary/greeter.rb
module Lapidary
  class Greeter
    def call(name)
      "Hello, #{name}!"
    end
  end
end
```

Resolve it from the container:

```ruby
Lapidary::Container['greeter']
```

Or inject it into another class:

```ruby
class MyService
  include Lapidary::Dependency['greeter']
end
```

## Providers

Providers in `system/providers/` register external services into the container. Each provider wraps a third-party dependency (e.g., database connection, HTTP client) and makes it available for injection.

Providers are started during `Container.finalize!` and follow the dry-system provider lifecycle (`prepare` → `start` → `stop`).
