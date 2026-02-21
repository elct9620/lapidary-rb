# Lapidary

[![CI](https://github.com/elct9620/lapidary-rb/actions/workflows/ci.yml/badge.svg)](https://github.com/elct9620/lapidary-rb/actions/workflows/ci.yml)

An experimental project exploring the use of LLM and ontology techniques to analyze relationships between Ruby contributors and core modules.

## Overview

Lapidary builds a knowledge graph from [bugs.ruby-lang.org](https://bugs.ruby-lang.org/) to help researchers understand the evolution of the Ruby language and community collaboration patterns. It ingests issue data via webhooks, fetches complete issue details (including journals for participant tracking) from the Redmine JSON API, and stores structured data in SQLite for future ontology and graph analysis.

## Features

- **Webhook endpoint** -- Receives issue change notifications (`POST /webhook`) with validation and error handling
- **Issue data fetching** -- Retrieves complete issue data from the Redmine JSON API, including journals to track discussion participants beyond the original author
- **SQLite storage** -- Persists issue data with upsert semantics (insert or full update keyed by issue ID)
- **Health check** -- `GET /` returns application availability status
- **Container deployment** -- Multi-stage Docker build for production deployment

## Tech Stack

- **Ruby 3.4** with **Sinatra** (web framework) and **Falcon** (async HTTP server)
- **dry-system** for dependency injection and component management
- **Zeitwerk** for autoloading
- **SQLite** + **Sequel** for data storage

## Getting Started

### Prerequisites

- Ruby 3.4

### Setup

```bash
bundle install
```

### Run the server

```bash
falcon host
```

The server binds to `0.0.0.0:9292` by default.

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

Set the `PORT` environment variable to change the listen port (default: `9292`).

## Project Structure

```
config/
  environment.rb       # Environment loader
  web.rb               # Main Rack app, composes controllers
apps/
  <domain>/            # Domain modules (Zeitwerk autoloaded)
    api.rb             # JSON API controller
lib/lapidary/          # Auto-registered shared components
system/providers/      # External service providers (database, HTTP client)
config.ru              # Rack entry point
falcon.rb              # Falcon server configuration
```

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

## License

[Apache-2.0](LICENSE)
