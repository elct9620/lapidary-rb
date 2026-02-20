# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lapidary is a Ruby web application built with **Sinatra** (Rack-based DSL) and served by **Falcon** (async HTTP server). The project is in its early stage.

## Commands

```bash
# Install dependencies
bundle install

# Run the server (via Falcon)
falcon host

# Run the server (via Rack)
bundle exec rackup

# Lint
bundle exec rubocop

# Lint with auto-fix
bundle exec rubocop --autocorrect
```

## Architecture

- `app.rb` — Main Sinatra application class (`App < Sinatra::Base`)
- `config.ru` — Rack entry point, loads and runs `App`
- `falcon.rb` — Falcon server configuration for async hosting

## Conventions

- All Ruby files must include `# frozen_string_literal: true`
- RuboCop is configured with `NewCops: enable` — all new cops are opted in by default
- A PostToolUse hook automatically runs RuboCop with `--autocorrect` on any `.rb` file after edits
