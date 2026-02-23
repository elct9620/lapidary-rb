# Lapidary

[![CI](https://github.com/elct9620/lapidary-rb/actions/workflows/ci.yml/badge.svg)](https://github.com/elct9620/lapidary-rb/actions/workflows/ci.yml)

An experimental project exploring the use of LLM and ontology techniques to analyze relationships between Ruby contributors and core modules.

## Overview

Lapidary builds a knowledge graph from [bugs.ruby-lang.org](https://bugs.ruby-lang.org/) to help researchers understand the evolution of the Ruby language and community collaboration patterns. It ingests issue data via webhooks, fetches complete issue details (including journals for participant tracking) from the Redmine JSON API, and stores structured data in SQLite for future ontology and graph analysis.

## Features

- **Webhook endpoint** -- Receives issue change notifications (`POST /webhook`) with validation and error handling
- **Redmine API integration** -- Fetches complete issue data from the Redmine JSON API, including journals for participant tracking beyond the original author
- **Job queue** -- Database-backed job queue for reliable async processing of analysis work
- **Analysis service** -- Background worker (Falcon-managed) that dequeues and processes analysis jobs sequentially
- **Incremental analysis** -- Tracks analyzed entities (Issues and Journals) to avoid redundant processing
- **SQLite storage** -- Persists issue data and analysis records with upsert semantics
- **Health check** -- `GET /` returns application availability status
- **Container deployment** -- Multi-stage Docker build for production deployment

## Tech Stack

- **Ruby 3.4** with **Sinatra** (web framework) and **Falcon** (async HTTP server)
- **dry-system** for dependency injection and component management
- **dry-validation** for request validation contracts
- **Zeitwerk** for autoloading
- **SQLite** + **Sequel** for data storage and migrations

## Getting Started

### Prerequisites

- Ruby 3.4

### Setup

```bash
bundle install
bundle exec rake db:migrate
```

### Run the server

```bash
falcon host
```

The server binds to `0.0.0.0:9292` by default. Falcon manages both the HTTP server and the Analysis Service as supervised background processes.

### Database

```bash
bundle exec rake db:migrate                # Run pending migrations
bundle exec rake 'db:generate[description]' # Generate a new migration file
```

SQLite is used for all environments. Development and production use file-based databases (`data/<env>.sqlite3`) with WAL journal mode. Tests use in-memory SQLite for speed and isolation.

### Run tests

```bash
bundle exec rspec
```

### Lint

```bash
bundle exec rubocop
```

## Docker

### Build

```bash
docker build -t lapidary .
```

### Run

```bash
docker run -p 9292:9292 lapidary
```

## Project Structure

```
apps/
  analysis/              # Analysis bounded context (outer layer)
    repositories/        # Database adapters (job + analysis record)
  health/                # Health check controller
  webhooks/              # Webhooks bounded context (outer layer)
    adapters/            # Cross-context adapters (ACL)
    repositories/        # Database + API adapters
    contract.rb          # Request validation
    api.rb               # Webhook API controller
lib/
  lapidary/              # Shared infrastructure (auto-registered)
    analysis/            # Falcon background worker service
  analysis/              # Analysis domain (inner layer)
    entities/            # Job, AnalysisRecord
    use_cases/           # ProcessJob
  webhooks/              # Webhooks domain (inner layer)
    entities/            # Issue, Journal, AnalysisRecord
    use_cases/           # HandleWebhook
  redmine/               # Redmine API client
system/providers/        # External service providers (database, logger, redmine)
db/migrations/           # Sequel database migrations
config/
  environment.rb         # Environment loader
  web.rb                 # Main Rack app, composes controllers
config.ru                # Rack entry point
falcon.rb                # Falcon server configuration (HTTP + analysis worker)
```

## Architecture

The application follows **Clean Architecture** organized by **bounded contexts** (Webhooks, Analysis). Inner layers (entities, use cases) live under `lib/<domain>/` and have no framework dependencies. Outer layers (controllers, repositories, adapters) live under `apps/<domain>/` and bridge the domain with infrastructure.

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation and [SPEC.md](SPEC.md) for behavioral specification.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `RACK_ENV` | `development` | Affects database path and Sinatra environment |
| `PORT` | `9292` | HTTP listen port (Falcon only) |

## License

[Apache-2.0](LICENSE)
