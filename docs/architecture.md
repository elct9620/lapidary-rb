# Architecture

## Overview

Lapidary is built on **Sinatra** (Rack-based web DSL), served by **Falcon** (async HTTP server), and uses **dry-system** for dependency injection. Data is stored in **SQLite** via **Sequel**.

For project goals, behavior specifications, and technical decisions, see [SPEC.md](../SPEC.md).

## System Layers

```
┌─────────────────────────────────┐
│  Application (apps/)            │  Domain modules (Zeitwerk autoloaded)
├─────────────────────────────────┤
│  Infrastructure (lib/lapidary/) │  Auto-registered shared components
├─────────────────────────────────┤
│  Providers (system/providers/)  │  External services (database, HTTP client)
└─────────────────────────────────┘
```

### Application Layer

`apps/` contains application-level components organized by domain. Each subdirectory represents a domain (e.g., `apps/webhooks/`) and contains that domain's controllers, use cases, entities, repositories, and contracts. The directory is registered as a `component_dirs` entry in the dry-system container and autoloaded via Zeitwerk (dry-system `:zeitwerk` plugin) — no manual `require` is needed. Components auto-register by default; individual files use the `# auto_register: false` magic comment to opt out.

`config/web.rb` defines `Lapidary::Web`, the main Rack application that composes all API controllers via Sinatra's `use` middleware mechanism. Each API class inherits from `Lapidary::BaseController` and handles specific routes. `Lapidary::Web` exposes `Web.container` for accessing the DI container.

### Infrastructure Layer

Components under `lib/lapidary/` are auto-registered by dry-system. This layer contains shared infrastructure such as fetching issue data and persisting records. Components are resolved by container key with the `lapidary` namespace stripped (e.g., `lib/lapidary/services/foo.rb` → `Container['services.foo']`).

### Providers

`system/providers/` hosts dry-system providers that register external services (database connections, HTTP clients) into the container. These are resolved at container finalization time.

### Application Layer Convention

`apps/` follows a domain-based convention where each subdirectory represents a domain:

- `apps/health/` — Health check endpoint
- `apps/webhooks/` — Webhook processing (issue notifications)
- Additional domains use the same pattern

Each domain directory contains components categorized by Clean Architecture layer:

| Component | Layer | `auto_register: false`? | Uses `Lapidary::Dependency`? | Description |
|---|---|---|---|---|
| Controller | Adapter (outer) | Yes — mounted via `use`, not resolved | Yes | Sinatra controller handling HTTP routes |
| Use Case | Domain (inner) | Yes — assembled by controller | **No** — plain constructor injection | Business logic orchestration |
| Entity | Domain (inner) | Yes — domain object | **No** — no DI | Domain value/data objects |
| Repository | Adapter (outer) | No — auto-registered | Yes | Data access, bridges domain and infrastructure |
| Contract | Adapter (outer) | No — auto-registered | N/A | Request validation via `dry-validation` |

**Dependency direction rule:** Inner layers (Entity, Use Case) must never depend on outer layers (Framework, Infrastructure). Only outer-layer components (Controller, Repository) may use `Lapidary::Dependency` (`Dry::AutoInject`). Inner-layer components receive dependencies through plain Ruby constructor injection, keeping the dependency direction always pointing inward.

Controllers (outer layer) resolve dependencies from the container and assemble Use Cases (inner layer):

```ruby
# Controller wires dependencies into Use Case
use_case = HandleWebhook.new(analysis_record_repository: analysis_record_repository)
output = use_case.call(issue_id)
```

Zeitwerk autoloads all constants under `apps/` — no manual `require` is needed. The directory structure maps to Ruby module namespaces (e.g., `apps/webhooks/api.rb` → `Webhooks::API`).

## V1 Data Flow

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
Check data completeness
  │
  ├─ incomplete → respond 200 (skipped)
  │
  ▼
Upsert into SQLite (keyed by issue id)
  │
  ▼
Create analysis records (issue + untracked journals)
  │  failure does not affect response
  │
  ▼
Respond 200 (ok)
```

## Directory Structure

```
config/
  environment.rb       # Environment loader (container + web app)
  web.rb               # Lapidary::Web — main Rack app, composes controllers
apps/
  health/
    api.rb             # Controller (adapter)
  webhooks/
    api.rb             # Controller (adapter)
    handle_webhook.rb  # Use Case (domain)
    analysis_record.rb # Entity (domain)
    analysis_record_repository.rb  # Repository (adapter)
    contract.rb        # Contract (adapter)
lib/lapidary/          # Auto-registered components
system/providers/      # External service providers (database, HTTP client, etc.)
config.ru              # Rack entry point
falcon.rb              # Falcon server configuration
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
