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

`apps/` contains application-level components organized by domain. Each subdirectory represents a domain (e.g., `apps/misc/`) and contains that domain's API controllers, models, jobs, and other objects. The directory is registered as a `component_dirs` entry in the dry-system container with `auto_register: false` and autoloaded via Zeitwerk (dry-system `:zeitwerk` plugin) — no manual `require` is needed.

`config/web.rb` defines `Lapidary::Web`, the main Rack application that composes all API controllers via Sinatra's `use` middleware mechanism. Each API class inherits from `Lapidary::BaseController` and handles specific routes. `Lapidary::Web` exposes `Web.container` for accessing the DI container.

### Infrastructure Layer

Components under `lib/lapidary/` are auto-registered by dry-system. This layer contains shared infrastructure such as fetching issue data and persisting records. Components are resolved by container key with the `lapidary` namespace stripped (e.g., `lib/lapidary/services/foo.rb` → `Container['services.foo']`).

### Providers

`system/providers/` hosts dry-system providers that register external services (database connections, HTTP clients) into the container. These are resolved at container finalization time.

### Application Layer Convention

`apps/` follows a domain-based convention where each subdirectory represents a domain:

- `apps/misc/` — Miscellaneous routes (root endpoint)
- Additional domains (e.g., `apps/webhooks/`, `apps/issues/`) use the same pattern

Each domain directory contains Sinatra controllers such as `api.rb` (JSON API) or `web.rb` (HTML pages), and may include both. Additional layer types (e.g., models, services) can be added as needed.

Zeitwerk autoloads all constants under `apps/` — no manual `require` is needed. The directory structure maps to Ruby module namespaces (e.g., `apps/misc/api.rb` → `Misc::API`).

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
Respond 200 (ok)
```

## Directory Structure

```
config/
  environment.rb       # Environment loader (container + web app)
  web.rb               # Lapidary::Web — main Rack app, composes controllers
apps/
  misc/                # Domain: miscellaneous routes (Zeitwerk autoloaded)
    api.rb             # Misc::API controller
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
